# frozen_string_literal: true

# :markup: markdown

require "active_record/connection_adapters/ractor_connection_handler"
require "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter/query_request"
require "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter/query_response"
require "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter/schema_creation_proxy"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      # Worker-Ractor stand-in for a concrete adapter. It runs the ordinary
      # worker-side query pipeline locally and forwards everything else to a
      # token-pinned physical connection on the main Ractor. Adapters opt in
      # through a subclass (MysqlProxyAdapter, PostgreSQLProxyAdapter,
      # SQLite3ProxyAdapter) that hand-defines their remote surface.
      class AbstractProxyAdapter < AbstractAdapter # :nodoc:
        include Proxy

        ADAPTER_NAME = "RactorProxy"

        PLACEHOLDER_LOGGER = Object.new.freeze

        # Methods that never touch the database: quoting/typing helpers and
        # feature flags. method_missing dispatches of such methods must not
        # materialize lazy worker-side transactions.
        PURE_REMOTE_METHOD_PATTERN = /\A(?:quote|type_to_sql\z|valid_type\?\z|supports_)/

        def initialize(pool, connection_token, profile, config)
          @adapter_profile = profile
          super(nil, PLACEHOLDER_LOGGER, nil, config)
          @connection_token = connection_token
          @logger = nil
          @pool = pool
          @prepared_statements = profile[:prepared_statements]
          @raw_connection = connection_token
          @verified = true
          @remote_capability_memo = {}
          @quoted_column_names = {}
          @quoted_table_names = {}
          @last_query_response = nil
        end

        def adapter_name
          @adapter_profile[:adapter_name]
        end

        # The token naming this proxy's pinned main-side connection; nil once
        # released.
        attr_reader :connection_token # :nodoc:

        # Whether this proxy still holds a token-pinned main-side connection.
        # For the state of the underlying physical connection, use #active?.
        def connected?
          !@connection_token.nil?
        end

        def active?
          connected? && !!remote_adapter_call(:active?)
        end

        def verify!
          remote_adapter_call(:verify!)
          @needs_reconnect = false
          @verified = true
          self
        end

        def connect!
          unless connected?
            raise ConnectionNotEstablished, "The Ractor-pinned connection has been released"
          end
          verify!
        end

        def reconnect!(restore_transactions: false)
          # The physical side always reconnects clean: transaction state is
          # worker-owned, so restoring is the worker manager's job — it
          # re-materializes through the bridged verbs (rebuilding the main-side
          # mirrors) and emits the restart instrumentation, exactly like a
          # single-manager adapter.
          remote_adapter_call(:reconnect!, [], { restore_transactions: false })
          reset_transaction(restore: restore_transactions) { }
          @needs_reconnect = false
          @verified = true
          self
        end

        def disconnect!
          # Matches AbstractAdapter semantics: closes the physical connection
          # but keeps it leased (token-pinned); the next use reconnects.
          # Returning the token to the pool here would strand the worker-side
          # lease on a dead proxy.
          remote_adapter_call(:disconnect!) if @connection_token
          @needs_reconnect = false
          @verified = false
          reset_transaction
        end

        def discard!
          if token = @connection_token
            @connection_token = nil
            @raw_connection = nil
            discard_token(token)
          end
          reset_transaction
        end

        def reset!
          remote_adapter_call(:reset!)
          reset_transaction
          self
        end

        def release_connection
          if token = @connection_token
            @connection_token = nil
            @raw_connection = nil
            checkin_token(token)
          end
        end

        # Backs ProxyConnectionPool#remove (AbstractAdapter#throw_away!).
        def remove_connection
          if token = @connection_token
            @connection_token = nil
            @raw_connection = nil
            remove_token(token)
          end
        end

        # Prepared statements (and their memoized column sets) live on the
        # physical connection; clearing only the worker-side state would leave
        # them stale after DDL (e.g. Model.reset_column_information).
        def clear_cache!(new_connection: false)
          super
          remote_adapter_call(:clear_cache!, [], { new_connection: new_connection }) if @connection_token
        end

        # Whether this proxy's token still names a live, checked-out main-side
        # connection (see connection_pinned?).
        def holds_main_connection? # :nodoc:
          !!(@connection_token && connection_pinned?(@connection_token))
        end

        def native_database_types
          remote_adapter_call(:native_database_types)
        end

        def valid_type?(type)
          !native_database_types[type].nil?
        end

        def quote_column_name(name)
          @quoted_column_names[name] ||= remote_adapter_call(:quote_column_name, [name])
        end

        def quote_table_name(name)
          @quoted_table_names[name] ||= remote_adapter_call(:quote_table_name, [name])
        end

        def type_casted_binds(binds)
          return [] if binds.nil? || binds.empty?

          token = @connection_token
          binds_payload = dump_binds(binds)
          main_operation(connection_pool: @pool) do
            shareable_copy(fetch_connection(token).type_casted_binds(Marshal.load(binds_payload)))
          end
        end

        # Mirrors AbstractAdapter#raw_connection against the physical
        # connection: lazily begun worker transactions materialize first and
        # the connection counts as dirty. The raw handle cannot cross the
        # dispatch boundary, so it is fetched from the registry directly and
        # only a main-Ractor caller may hold it.
        def raw_connection
          unless ActiveSupport::Ractors.main?
            raise ActiveRecordError, "The raw connection of a Ractor-proxied connection can only be accessed from the main Ractor"
          end
          unless @connection_token
            raise ConnectionNotEstablished, "The Ractor-pinned connection has been released"
          end

          materialize_transactions
          disable_lazy_transactions!
          @raw_connection_dirty = true
          Proxy.fetch_connection(@connection_token).raw_connection
        end

        # Checkout/checkin callbacks are class-level AS::Callbacks state, which
        # is not Ractor-shareable in general (applications and tests register
        # procs on AbstractAdapter), so a worker cannot traverse it. They are a
        # physical-connection concern anyway: the concrete adapter runs them
        # main-side when the token-pinned connection returns to the real pool.
        # Intercepted at run_callbacks (set_callback regenerates the outer
        # _run_*_callbacks methods); only the essential local bookkeeping the
        # caller wraps runs here.
        def run_callbacks(kind, &block) # :nodoc:
          if kind == :checkin || kind == :checkout
            block ? yield : nil
          else
            super
          end
        end

        # Arel compilation runs locally: the concrete visitor class comes from
        # the connection profile (see #arel_visitor), and its connection
        # callbacks (quote, quote_table_name, cast_bound_value, ...) dispatch
        # individually as pure remote calls. `unprepared_statement` state and
        # collector semantics (preparable/retryable) are worker-local, exactly
        # as on a single-manager adapter, so AbstractAdapter#to_sql_and_binds
        # needs no override.

        # Raw driver results cannot cross the Ractor boundary; `execute`
        # returns a materialized ActiveRecord::Result instead.
        def execute(sql, name = nil, allow_retry: false)
          # The dirtying wrapper QueryCache.dirties_query_cache installed on
          # AbstractAdapter#execute is shadowed by this override; replicate it.
          if pool.dirties_query_cache
            ActiveRecord::Base.clear_query_caches_for_current_thread
          end

          intent = internal_build_intent(sql, name, allow_retry: allow_retry)
          intent.execute!
          intent.cast_result
        end

        # DDL is rendered by the concrete adapter's SchemaCreation on the main
        # Ractor; the concrete `schema_creation` object itself holds the raw
        # connection and cannot cross the boundary.
        def schema_creation # :nodoc:
          SchemaCreationProxy.new(self)
        end

        # Renders one schema definition object (e.g. CreateIndexDefinition)
        # with the concrete adapter's SchemaCreation visitor and returns the
        # DDL string. Schema statements only ever run on the main Ractor
        # (migrations, test-suite DDL), so definition rendering refuses worker
        # callers instead of marshaling definition graphs across the boundary.
        def remote_schema_creation_accept(node) # :nodoc:
          unless ActiveSupport::Ractors.main?
            raise ActiveRecordError, "Schema statements can only be executed on the main Ractor"
          end

          token = @connection_token
          main_operation(connection_pool: @pool) do
            fetch_connection(token).schema_creation.accept(node)
          end
        end

        # InsertAll SQL is rendered by the concrete adapter against the live
        # builder, which (like schema definition graphs) cannot cross the
        # boundary, so insert_all/upsert_all is main-Ractor only.
        def build_insert_sql(insert) # :nodoc:
          unless ActiveSupport::Ractors.main?
            raise ActiveRecordError, "insert_all/upsert_all can only be executed on the main Ractor"
          end
          unless @connection_token
            raise ConnectionNotEstablished, "The Ractor-pinned connection has been released"
          end

          materialize_transactions
          Proxy.fetch_connection(@connection_token).build_insert_sql(insert)
        end

        # See #begin_main_transaction: the worker-materialized transaction
        # reaches the physical connection through its own TransactionManager,
        # keeping the main side aware of the worker's transaction depth.
        #
        # The begin verbs run under with_raw_connection(allow_retry: true),
        # matching the concrete adapters' own BEGIN commands.
        def begin_db_transaction # :nodoc:
          with_raw_connection(allow_retry: true, materialize_transactions: false) do
            begin_main_transaction(nil, true)
          end
        end

        def begin_isolated_db_transaction(isolation) # :nodoc:
          with_raw_connection(allow_retry: true, materialize_transactions: false) do
            begin_main_transaction(isolation, true)
          end
        end

        def begin_deferred_transaction(isolation_level = nil) # :nodoc:
          with_raw_connection(allow_retry: true, materialize_transactions: false) do
            begin_main_transaction(isolation_level, false)
          end
        end

        # Commit/rollback/restart run under with_raw_connection like the
        # concrete adapters' own COMMIT/ROLLBACK commands, so a connection
        # error downgrades the worker-side state (@verified/@needs_reconnect)
        # and the next use verify-reconnects instead of trusting a dead
        # connection. No retry: whether a failed COMMIT landed is unknowable.
        def commit_db_transaction # :nodoc:
          with_raw_connection(materialize_transactions: false) do
            commit_main_transaction
          end
        end

        def exec_rollback_db_transaction # :nodoc:
          with_raw_connection(materialize_transactions: false) do
            rollback_main_transaction
          end
        end

        def exec_restart_db_transaction # :nodoc:
          with_raw_connection(materialize_transactions: false) do
            remote_adapter_call(:restart_db_transaction)
          end
        end

        private
          # The concrete adapter's visitor, bound to this proxy: dialect SQL
          # generation runs on the worker, and the visitor's quoting callbacks
          # reach the physical connection through the proxy's remote dispatch.
          def arel_visitor
            @adapter_profile[:arel_visitor_class].new(self)
          end

          # From the profile: consulted on every prepared compile
          # (to_sql_and_binds), so it must not cost a dispatch.
          def bind_params_length
            @adapter_profile[:bind_params_length]
          end

          # Definition objects are built locally (the caller's block mutates
          # them) with the concrete adapter's TableDefinition class, so
          # adapter-specific column semantics (e.g. SQLite3 integer references)
          # are preserved. Rendering goes through SchemaCreationProxy and is
          # main-Ractor only.
          def create_table_definition(name, **options)
            table_definition_class.new(self, name, **options)
          end

          def table_definition_class
            @adapter_profile[:table_definition_class]
          end

          def adapter_class
            @adapter_profile[:adapter_class]
          end

          # The concrete adapter's type map, not AbstractAdapter's generic one:
          # local casting must match the adapter (e.g. SQLite3's 8-byte integer
          # limit). Requires the adapter's TYPE_MAP to be Ractor-shareable to
          # work from a worker Ractor.
          def type_map
            if key = extended_type_map_key
              adapter_class::EXTENDED_TYPE_MAPS.compute_if_absent(key) do
                adapter_class.extended_type_map(**key)
              end
            else
              adapter_class::TYPE_MAP
            end
          end

          def build_statement_pool
            # Prepared statements are managed by the concrete adapter on the
            # main Ractor.
            nil
          end

          def perform_query(_raw_connection, intent)
            request = QueryRequest.new(
              sql: intent.processed_sql,
              binds: intent.binds,
              name: intent.name,
              prepare: intent.prepare,
              batch: intent.batch,
              allow_retry: intent.allow_retry,
            )

            token = @connection_token
            response = main_operation(sql: request.sql, connection_pool: @pool) do
              request.perform(fetch_connection(token))
            end
            @last_query_response = response
            intent.notification_payload[:affected_rows] = response.affected_rows
            intent.notification_payload[:row_count] = response.row_count
            response
          end

          def cast_result(response)
            return response if response.is_a?(ActiveRecord::Result)

            response.to_result
          end

          def affected_rows(response)
            response.affected_rows
          end

          def collect_warnings(response)
            response.is_a?(QueryResponse) ? response.warnings : []
          end

          # The generated ID as computed by the concrete adapter on the main
          # Ractor right after the query (e.g. `last_id` for MySQL inserts
          # without RETURNING).
          def last_inserted_id(_result)
            @last_query_response&.last_inserted_id
          end

          # Forwards one DB-touching adapter method to the token-pinned
          # main-Ractor connection. Remote adapter methods may write through
          # the physical connection (e.g. SQLite3#add_column); a lazily begun
          # worker-side transaction must reach it first, or rolling the
          # transaction back would not cover the remote work.
          def remote_dispatch(method_name, *args, **kwargs, &block)
            if block
              raise ActiveRecordError, "Cannot forward a block to #{method_name} on the main-Ractor connection"
            end

            materialize_transactions
            remote_adapter_call(method_name, args, kwargs)
          end

          # Forwards an adapter method that never touches the database
          # (capabilities, quoting, typing); must not materialize lazy
          # worker-side transactions.
          def pure_remote_dispatch(method_name, *args, **kwargs, &block)
            if block
              raise ActiveRecordError, "Cannot forward a block to #{method_name} on the main-Ractor connection"
            end

            remote_adapter_call(method_name, args, kwargs)
          end

          def remote_adapter_call(method_name, args = [], kwargs = {})
            if args.empty? && kwargs.empty? && CAPABILITY_METHOD_PATTERN.match?(method_name)
              capabilities = @adapter_profile[:capabilities]
              if capabilities&.key?(method_name)
                return capabilities[method_name]
              end
            end

            unless @connection_token
              raise ConnectionNotEstablished, "The Ractor-pinned connection has been released"
            end

            if args.empty? && kwargs.empty? && CAPABILITY_METHOD_PATTERN.match?(method_name)
              @remote_capability_memo.fetch(method_name) do
                @remote_capability_memo[method_name] = call_main_connection(method_name, args, kwargs)
              end
            else
              call_main_connection(method_name, args, kwargs)
            end
          end

          # Generic dispatch of one adapter method to the token-pinned
          # connection. Arguments and results always cross as shareable copies,
          # keeping a self-proxy run faithful to the worker boundary.
          def call_main_connection(method_name, args, kwargs)
            token = @connection_token
            shareable_args = shareable_args_copy(args)
            shareable_kwargs = shareable_kwargs_copy(kwargs)

            main_operation(connection_pool: @pool) do
              shareable_copy(fetch_connection(token).__send__(method_name, *shareable_args, **shareable_kwargs))
            end
          end

          # Transaction verbs cross at the TransactionManager level of the
          # token-pinned connection (not as raw BEGIN/COMMIT SQL), so the
          # physical connection's own manager always tracks the worker's
          # transaction depth: a remote method that opens its own transaction
          # (e.g. SQLite3#alter_table) then nests as a savepoint instead of
          # issuing a second BEGIN. The mirror carries the worker
          # transaction's joinable flag, so both remote-side `transaction`
          # nesting and adapter-specific BEGIN modes (e.g. SQLite immediate vs
          # deferred) behave exactly as in a single-manager run. The mirror
          # emits no transaction.active_record events: the connection is
          # `proxied`, and the worker-side proxy's manager instruments.
          def begin_main_transaction(isolation, joinable)
            token = @connection_token
            main_operation(connection_pool: @pool) do
              fetch_connection(token).begin_transaction(isolation: isolation, joinable: joinable, _lazy: false)
              nil
            end
          end

          # Commit/rollback tolerate a lost mirror: a main-side component that
          # resets the physical connection (disconnect!, reset!, verify-
          # reconnect) clears the main manager together with the physical
          # transaction, and the worker's later verb has nothing left to act
          # on — exactly as a single-manager adapter would behave.
          def commit_main_transaction
            token = @connection_token
            main_operation(connection_pool: @pool) do
              connection = fetch_connection(token)
              connection.commit_transaction if connection.transaction_open?
              nil
            end
          end

          def rollback_main_transaction
            token = @connection_token
            main_operation(connection_pool: @pool) do
              connection = fetch_connection(token)
              connection.rollback_transaction if connection.transaction_open?
              nil
            end
          end

          def method_missing(name, *args, **kwargs, &block)
            return super if name == :marshal_dump || name == :_dump

            if block
              raise ActiveRecordError, "Cannot forward a block to #{name} on the main-Ractor connection"
            end

            # See #remote_dispatch: remote work must land inside a lazily
            # begun worker-side transaction.
            materialize_transactions unless PURE_REMOTE_METHOD_PATTERN.match?(name)
            remote_adapter_call(name, args, kwargs)
          end

          def respond_to_missing?(name, include_private = false)
            return false if name == :marshal_dump || name == :_dump

            super
          end
      end
    end
  end
end
