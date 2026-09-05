# frozen_string_literal: true

# :markup: markdown

require "ractor/dispatch"
require "active_record/connection_adapters/ractor_connection_proxy/query_request"
require "active_record/connection_adapters/ractor_connection_proxy/query_response"
require "active_record/connection_adapters/ractor_connection_proxy/schema_creation_proxy"
require "active_record/connection_adapters/ractor_connection_proxy/visitor_proxy"

module ActiveRecord
  module ConnectionAdapters
    # Worker-Ractor stand-in for a concrete adapter. It runs the ordinary
    # worker-side query pipeline locally and forwards everything else to a
    # token-pinned physical connection on the main Ractor.
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      ADAPTER_NAME = "RactorProxy"

      CAPABILITY_METHOD_PATTERN = /\Asupports_.*\?\z/
      PLACEHOLDER_LOGGER = Object.new.freeze

      # Raised on the worker when the main-side error class cannot be
      # reconstructed. Preserves the original class name.
      class RemoteError < ActiveRecordError
        attr_reader :remote_class_name

        def initialize(message = nil, remote_class_name = nil)
          @remote_class_name = remote_class_name
          super(message)
        end
      end

      # Shareable response describing a main-side failure. The worker
      # reconstructs and raises the original exception class from it.
      class ErrorResponse
        attr_reader :class_name, :message, :sql, :backtrace

        def initialize(error, sql: nil)
          @class_name = error.class.name.to_s
          @message = error.message.to_s
          @sql = ((error.respond_to?(:sql) && error.sql) || sql)&.to_s
          @backtrace = error.backtrace
          ActiveSupport::Ractors.make_shareable(self, copy: false)
        rescue Ractor::Error
          @backtrace = nil
          ActiveSupport::Ractors.make_shareable(self, copy: false)
        end
      end

      # Main-Ractor-only registry of token-pinned physical connections. Pool
      # tokens are minted from the same sequence: every identity that crosses
      # the Ractor boundary is a token issued here.
      @connections = {}
      @pool_tokens = ObjectSpace::WeakKeyMap.new
      @next_token = 0
      @connections_lock = Mutex.new

      # Main-Ractor-only cache of computed per-adapter-class transport
      # surfaces.
      @remote_adapter_methods = {}.compare_by_identity

      class << self
        attr_reader :connections

        # Identity token of a main-Ractor pool instance, minted rather than a
        # raw object id (object ids can be recycled after GC, which could
        # alias a replaced pool with a fresh one). Re-establishing a
        # connection replaces the pool and therefore its token.
        def pool_token(pool)
          @connections_lock.synchronize { @pool_tokens[pool] ||= (@next_token += 1) }
        end

        def checkout_connection(connection_name, role, shard)
          shareable_connection_name = shareable_copy(connection_name.to_s)
          main_operation do
            connection = main_pool(shareable_connection_name, role, shard).checkout
            token = register_connection(connection)
            ActiveSupport::Ractors.make_shareable([token, connection_profile(connection)], copy: true)
          end
        end

        def checkin_connection(connection_token)
          main_operation do
            if connection = take_back_connection(connection_token)
              connection.pool.checkin(connection) if connection.in_use?
            end
            nil
          end
        end

        # Backs `AbstractAdapter#throw_away!` on the worker.
        def remove_connection(connection_token)
          main_operation do
            if connection = take_back_connection(connection_token)
              connection.pool.remove(connection)
              connection.disconnect!
            end
            nil
          end
        end

        def discard_connection(connection_token)
          main_operation do
            if connection = take_back_connection(connection_token)
              connection.pool.remove(connection)
              connection.discard!
            end
            nil
          end
        end

        # External lifecycle hook: releases every token-pinned connection.
        # Intended for supervisors that tear down worker Ractors, since a
        # worker that dies abruptly cannot release its own tokens.
        def checkin_all_connections
          main_operation do
            @connections_lock.synchronize do
              @connections.each_value do |connection|
                reclaim(connection)
                connection.pool.checkin(connection) if connection.in_use?
              end
              @connections.clear
            end
            nil
          end
        end

        # Forked children inherit the registry, but the underlying pools and
        # connections were just discarded (PoolConfig.discard_pools!); the
        # inherited tokens are dead and must not be checked back in.
        def forget_all_connections! # :nodoc:
          @connections_lock.synchronize { @connections.clear }
        end

        # Whether the token still names a live, checked-out main-side
        # connection. False once anything main-side took the physical
        # connection back (e.g. ActiveRecord.disconnect_all! on the real
        # pools).
        def connection_pinned?(connection_token)
          main_operation do
            connection = @connections_lock.synchronize { @connections[connection_token] }
            !!(connection && connection.in_use?)
          end
        end

        def main_pool_specs(role = nil)
          copy = !ActiveSupport::Ractors.main?
          main_operation do
            specs = main_connection_handler.connection_pool_list(role).map do |pool|
              RactorConnectionPool.spec_for(pool, copy: copy)
            end
            copy ? ActiveSupport::Ractors.make_shareable(specs, copy: false) : specs
          end
        end

        def main_pool_spec(connection_name, role, shard, strict)
          shareable_connection_name = shareable_copy(connection_name.to_s)
          copy = !ActiveSupport::Ractors.main?
          main_operation do
            pool = main_connection_handler.retrieve_connection_pool(
              shareable_connection_name,
              role: role,
              shard: shard,
              strict: strict,
            )
            pool && RactorConnectionPool.spec_for(pool, copy: copy)
          end
        end

        def dispatch_to_main_pool(connection_name, role, shard, method_name, args, kwargs, connection_pool: nil)
          shareable_connection_name = shareable_copy(connection_name.to_s)
          shareable_args = shareable_copy(args)
          shareable_kwargs = shareable_copy(kwargs)
          dispatched_method = method_name.to_sym
          # Pool maintenance surfaces main-Ractor state (physical connections,
          # pool internals) that cannot cross a Ractor boundary. A main-Ractor
          # caller (self-proxy) crosses no boundary and may hold it directly.
          copy_result = !ActiveSupport::Ractors.main?

          main_operation(connection_pool: connection_pool) do
            result = main_pool(shareable_connection_name, role, shard)
              .__send__(dispatched_method, *shareable_args, **shareable_kwargs)
            copy_result ? shareable_copy(result) : result
          end
        end

        # Backs RactorConnectionPool#pin_connection!. Pins connection
        # identity only: the pinned transaction is driven by the worker so it
        # lives on the proxy's transaction manager, letting worker-side
        # transactions nest as savepoints.
        def pin_main_pool_connection(connection_name, role, shard, lock_thread, connection_pool: nil)
          shareable_connection_name = shareable_copy(connection_name.to_s)
          pin_lock_thread = !!lock_thread
          main_operation(connection_pool: connection_pool) do
            main_pool(shareable_connection_name, role, shard).pin_connection!(pin_lock_thread, transaction: false)
            nil
          end
        end

        # Backs RactorConnectionPool#unpin_connection!; the worker finishes
        # the pinned transaction before releasing the identity pin. The pin
        # dies with its pool: when the named pool was replaced or removed
        # (pool token mismatch), there is nothing left to unpin.
        def unpin_main_pool_connection(connection_name, role, shard, pool_token, connection_pool: nil)
          shareable_connection_name = shareable_copy(connection_name.to_s)
          main_operation(connection_pool: connection_pool) do
            pool = main_connection_handler.retrieve_connection_pool(
              shareable_connection_name, role: role, shard: shard, strict: false
            )
            pool.unpin_connection!(transaction: false) if pool && self.pool_token(pool) == pool_token
            nil
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
        # deferred) behave exactly as in a single-manager run.
        def begin_transaction_on_connection(connection_token, isolation, joinable, connection_pool: nil)
          main_operation(connection_pool: connection_pool) do
            connection = fetch_connection(connection_token)
            if isolation
              connection.begin_transaction(isolation: isolation, joinable: joinable, _lazy: false, instrument: false)
            else
              connection.begin_transaction(joinable: joinable, _lazy: false, instrument: false)
            end
            nil
          end
        end

        # Commit/rollback tolerate a lost mirror: a main-side component that
        # resets the physical connection (disconnect!, reset!, verify-
        # reconnect) clears the main manager together with the physical
        # transaction, and the worker's later verb has nothing left to act
        # on — exactly as a single-manager adapter would behave.
        def commit_transaction_on_connection(connection_token, connection_pool: nil)
          main_operation(connection_pool: connection_pool) do
            connection = fetch_connection(connection_token)
            connection.commit_transaction if connection.transaction_open?
            nil
          end
        end

        def rollback_transaction_on_connection(connection_token, connection_pool: nil)
          main_operation(connection_pool: connection_pool) do
            connection = fetch_connection(connection_token)
            connection.rollback_transaction if connection.transaction_open?
            nil
          end
        end

        def dispatch_to_main_schema_cache(connection_name, role, shard, method_name, args, kwargs, connection_token: nil, connection_pool: nil)
          shareable_connection_name = shareable_copy(connection_name.to_s)
          copy = !ActiveSupport::Ractors.main?
          shareable_args = copy ? shareable_copy(args) : args
          shareable_kwargs = copy ? shareable_copy(kwargs) : kwargs
          dispatched_method = method_name.to_sym

          main_operation(connection_pool: connection_pool) do
            pool = main_pool(shareable_connection_name, role, shard)
            schema_cache =
              if connection_token
                # A leased worker must observe its own uncommitted state
                # (e.g. DDL inside an open transaction), so lookups bind to
                # the token-pinned connection instead of letting the pool
                # check out a second one.
                BoundSchemaReflection.for_lone_connection(pool.schema_reflection, fetch_connection(connection_token))
              else
                pool.schema_cache
              end
            result = schema_cache.__send__(dispatched_method, *shareable_args, **shareable_kwargs)
            copy ? shareable_copy(result) : result
          end
        end

        # Generic dispatch of one adapter method to the token-pinned
        # connection. Arguments and results cross a Ractor boundary only for
        # off-main callers; a main-Ractor caller (self-proxy) passes and
        # receives the live objects, exactly as a direct adapter call would.
        def call_connection(connection_token, method_name, args, kwargs, connection_pool: nil)
          copy = !ActiveSupport::Ractors.main?
          shareable_args = copy ? shareable_copy(args) : args
          shareable_kwargs = copy ? shareable_copy(kwargs) : kwargs
          dispatched_method = method_name.to_sym

          main_operation(connection_pool: connection_pool) do
            connection = fetch_connection(connection_token)
            result = connection.__send__(dispatched_method, *shareable_args, **shareable_kwargs)
            copy ? shareable_copy(result) : result
          end
        end

        # The deliberate low-level query operation. Executes below the public
        # query pipeline: no main-side intent logging, no query transformers,
        # no main-side transaction bookkeeping — only connection readiness,
        # the concrete adapter's `perform_query`, and result materialization.
        def query_connection(connection_token, request, connection_pool: nil)
          main_operation(sql: request.sql, connection_pool: connection_pool) do
            perform_main_query(fetch_connection(connection_token), request)
          end
        end

        def cast_binds_on_connection(connection_token, binds, copy: true, connection_pool: nil)
          main_operation(connection_pool: connection_pool) do
            connection = fetch_connection(connection_token)
            result = connection.type_casted_binds(copy ? Marshal.load(binds) : binds)
            copy ? shareable_copy(result) : result
          end
        end

        # Compiles an Arel AST with the concrete adapter's `to_sql_and_binds`,
        # preserving its prepared-statement, collector, and retryability
        # semantics. Returns `[sql, binds_payload, preparable, allow_retry]`
        # (`binds` raw, not a payload, when `copy` is false).
        def compile_on_connection(connection_token, ast, preparable, allow_retry, prepared_statements: true, copy: true, connection_pool: nil)
          main_operation(connection_pool: connection_pool) do
            connection = fetch_connection(connection_token)
            compile = -> do
              connection.to_sql_and_binds(copy ? Marshal.load(ast) : ast, [], preparable, allow_retry)
            end
            sql, binds, compiled_preparable, compiled_allow_retry =
              if prepared_statements
                compile.call
              else
                # The worker sits inside an `unprepared_statement` section;
                # that state is execution-local, so it must be re-established
                # around the main-side compile (it substitutes binds).
                connection.unprepared_statement(&compile)
              end
            if copy
              ActiveSupport::Ractors.make_shareable(
                [sql, Marshal.dump(binds), compiled_preparable, compiled_allow_retry], copy: true
              )
            else
              [sql, binds, compiled_preparable, compiled_allow_retry]
            end
          end
        end

        # Compiles an Arel node with the concrete adapter's visitor and the
        # caller's collector, reconstructed on the main Ractor. Returns
        # `[value_payload, preparable, retryable]` (`value` raw when `copy`
        # is false).
        def visitor_compile_on_connection(connection_token, node, collector_payload, copy: true, connection_pool: nil)
          main_operation(connection_pool: connection_pool) do
            connection = fetch_connection(connection_token)
            compiled_node = copy ? Marshal.load(node) : node
            collector =
              case collector_payload
              when nil then Arel::Collectors::SQLString.new
              when :substitute_binds
                Arel::Collectors::SubstituteBinds.new(connection, Arel::Collectors::SQLString.new)
              else
                copy ? Marshal.load(collector_payload) : collector_payload
              end
            value = connection.visitor.compile(compiled_node, collector)
            preparable = collector.preparable if collector.respond_to?(:preparable)
            retryable = collector.retryable if collector.respond_to?(:retryable)
            if copy
              ActiveSupport::Ractors.make_shareable([Marshal.dump(value), preparable, retryable], copy: true)
            else
              [value, preparable, retryable]
            end
          end
        end

        # Renders one schema definition object (e.g. CreateIndexDefinition)
        # with the concrete adapter's SchemaCreation visitor. Returns the DDL
        # string. Main-Ractor only (see #remote_schema_creation_accept).
        def schema_creation_accept_on_connection(connection_token, node, connection_pool: nil)
          main_operation(connection_pool: connection_pool) do
            fetch_connection(connection_token).schema_creation.accept(node)
          end
        end

        # Methods that must keep their (worker-local) AbstractAdapter
        # implementations even when a concrete adapter overrides them: the
        # query pipeline entry points (which must build worker-side intents),
        # exception translation (main-side errors arrive pre-translated), and
        # physical connection machinery that only makes sense next to the raw
        # connection on the main Ractor.
        ALWAYS_LOCAL_METHODS = %i[
          execute exec_query exec_insert exec_delete exec_update exec_insert_all
          _exec_insert insert update delete truncate truncate_tables execute_batch
          select_all select_one select_value select_values select_rows
          query_all query_rows query_values query_value query_one query_command
          cacheable_query to_sql to_sql_and_binds
          translate_exception translate_exception_class retryable_query_error?
          type_map extended_type_map_key
          reconnect connect! configure_connection attempt_configure_connection
          check_version default_prepared_statements
          _run_checkin_callbacks _run_checkout_callbacks
        ].freeze

        # Per-Ractor cache of the remote-dispatch modules built from a connection profile.
        def remote_dispatch_module(profile)
          cache = (ActiveSupport::Ractors[:active_record_ractor_dispatch_modules] ||= {})
          cache[profile[:adapter_class_name]] ||= Module.new do
            profile[:remote_methods].each do |method_name|
              define_method(method_name) do |*args, **kwargs, &block|
                if block
                  raise ActiveRecordError,
                    "Cannot forward a block to #{method_name} on the main-Ractor connection"
                end
                # Remote adapter methods may write through the physical
                # connection (e.g. SQLite3#add_column); a lazily begun
                # worker-side transaction must reach it first, or rolling the
                # transaction back would not cover the remote work. Pure
                # reads (capabilities, quoting) never touch the database and
                # must not materialize a lazy transaction.
                materialize_transactions unless RactorConnectionProxy.pure_remote_method?(method_name)
                remote_adapter_call(method_name, args, kwargs)
              end
            end
          end
        end

        # Methods that never touch the database: quoting/typing helpers and
        # feature flags. Safe to dispatch without materializing lazy
        # worker-side transactions.
        PURE_REMOTE_METHOD_PATTERN = /\A(?:quote|type_to_sql\z|valid_type\?\z|supports_)/
        def pure_remote_method?(method_name)
          PURE_REMOTE_METHOD_PATTERN.match?(method_name)
        end

        # Only public because `on_main` blocks run with a nil `self`.
        def capture_transport_errors(sql: nil) # :nodoc:
          yield
        rescue => error
          ErrorResponse.new(error, sql: sql)
        end

        def raise_transport_error(response, connection_pool: nil) # :nodoc:
          klass = begin
            constant = Object.const_get(response.class_name)
            constant if constant.is_a?(Class) && constant <= Exception
          rescue NameError
            nil
          end

          error =
            begin
              if klass && klass <= ActiveRecord::StatementInvalid
                klass.new(response.message, sql: response.sql, connection_pool: connection_pool)
              elsif klass && klass <= ActiveRecord::AdapterError
                klass.new(response.message, connection_pool: connection_pool)
              elsif klass
                klass.new(response.message)
              end
            rescue ArgumentError, TypeError
              nil
            end

          error ||= RemoteError.new("#{response.class_name}: #{response.message}", response.class_name)
          error.set_backtrace(response.backtrace) if response.backtrace
          raise error
        end

        def shareable_copy(value)
          return value if ActiveSupport::Ractors.shareable?(value)

          copy = Marshal.load(Marshal.dump(value))
          ActiveSupport::Ractors.make_shareable(copy)
        end

        def dump_object(value, description)
          Marshal.dump(value).freeze
        rescue TypeError => error
          raise ActiveRecordError, "Cannot send #{description} across the Ractor boundary: #{error.message}"
        end

        def dump_binds(binds)
          return nil if binds.nil? || binds.empty?

          dump_object(binds, "bind parameters")
        end

        def dump_column_types(result)
          types = result.columns.map { |name| result.column_types[name] }
          return nil if types.all?(&:nil?)

          begin
            Marshal.dump(types).freeze
          rescue TypeError
            # Drop only the unmarshalable entries; `ActiveRecord::Result`
            # falls back to `Type.default_value` for nil entries.
            safe_types = types.map do |type|
              Marshal.dump(type)
              type
            rescue TypeError
              nil
            end
            Marshal.dump(safe_types).freeze
          end
        end

        private
          # Runs `block` on the main Ractor with `self` pinned to this class.
          # A main-Ractor caller (self-proxy) runs it inline and errors
          # propagate as the original exception objects. For a worker caller
          # the block must capture only shareable objects and return a
          # shareable value; a main-side error travels back as an
          # ErrorResponse and is re-raised on the calling side.
          def main_operation(sql: nil, connection_pool: nil, &block)
            if ActiveSupport::Ractors.main?
              begin
                return yield
              rescue ActiveRecordError => error
                # Main-side translation attached the physical pool; point the
                # error at the pool the caller actually holds, exactly as the
                # worker path's raise_transport_error does.
                if connection_pool && error.respond_to?(:connection_pool)
                  error.instance_variable_set(:@connection_pool, connection_pool)
                end
                raise
              end
            end

            operation = ActiveSupport::Ractors.shareable_proc(self: RactorConnectionProxy, &block)
            outcome = ActiveSupport::Ractors.on_main do
              RactorConnectionProxy.capture_transport_errors(sql: sql) { operation.call }
            end
            unwrap_transport_outcome(outcome, connection_pool: connection_pool)
          end

          def unwrap_transport_outcome(outcome, connection_pool: nil)
            raise_transport_error(outcome, connection_pool: connection_pool) if outcome.is_a?(ErrorResponse)
            outcome
          end

          def register_connection(connection)
            # Eager: a token-pinned connection is `leased`, so the pipeline's
            # ensure_connection_ready will neither connect nor verify it (see
            # skip_verification?); it must be usable up front.
            connection.connect!
            # Not folded into connect! (the shared bootstrap for every
            # adapter): only this callsite knows the connection is being
            # pinned. steal! clears the flag when the lease is taken back.
            connection.leased = true
            @connections_lock.synchronize do
              token = (@next_token += 1)
              @connections[token] = connection
              token
            end
          end

          def deregister_connection(connection_token)
            @connections_lock.synchronize { @connections.delete(connection_token) }
          end

          def take_back_connection(connection_token)
            if connection = deregister_connection(connection_token)
              reclaim(connection)
              connection
            end
          end

          def fetch_connection(connection_token)
            connection = @connections_lock.synchronize { @connections[connection_token] }
            unless connection
              raise ConnectionNotEstablished, "The Ractor-pinned connection for token #{connection_token.inspect} has been released"
            end
            connection
          end

          # Token-pinned connections are leased on whichever thread ran the
          # checkout operation (usually the dispatch executor). Reassign
          # ownership to the current thread so pool checkin/removal is legal
          # from any main-Ractor thread.
          def reclaim(connection)
            connection.steal! if connection.in_use?
          end

          def perform_main_query(connection, request)
            intent = QueryIntent.new(
              adapter: connection,
              processed_sql: request.sql,
              name: request.name,
              binds: request.binds,
              prepare: request.prepare,
              allow_retry: request.allow_retry,
              materialize_transactions: false,
              batch: request.batch,
            )
            # Concrete `perform_query` implementations record row counts here.
            intent.notification_payload = {}

            result, warnings, last_inserted_id = connection.execute_raw_intent(intent)

            QueryResponse.new(
              result,
              intent.notification_payload[:affected_rows] || result.affected_rows,
              intent.notification_payload[:row_count] || result.length,
              last_inserted_id,
              warnings,
            )
          end

          # The handler that owns the real pools on the main Ractor. Resolved
          # as `default_connection_handler` rather than `connection_handler`:
          # main-side dispatch threads carry no per-thread handler state, and
          # in a self-proxy run (tests on the main Ractor routed through the
          # Ractor handler) `connection_handler` would resolve back to the
          # proxying handler itself.
          def main_connection_handler
            ActiveRecord::Base.default_connection_handler
          end

          def main_pool(connection_name, role, shard)
            main_connection_handler.retrieve_connection_pool(
              connection_name,
              role: role,
              shard: shard,
              strict: true,
            )
          end

          def connection_profile(connection)
            klass = connection.class
            {
              adapter_class_name: klass.name,
              adapter_name: connection.adapter_name,
              prepared_statements: connection.instance_variable_get(:@prepared_statements),
              remote_methods: remote_adapter_methods(klass),
              referential_integrity_module_name: referential_integrity_module_name(klass),
              table_definition_class_name: connection.send(:create_table_definition, "__ractor_probe__").class.name,
              capabilities: capability_snapshot(connection),
            }
          end

          # Zero-arity feature flags answered up front, so workers never pay
          # a dispatch for them — and can still answer them after the token
          # has been released (e.g. a lazy transaction on a checked-in
          # connection).
          def capability_snapshot(connection)
            remote_adapter_methods(connection.class).each_with_object({}) do |method_name, snapshot|
              next unless CAPABILITY_METHOD_PATTERN.match?(method_name)
              next unless connection.respond_to?(method_name) && connection.method(method_name).arity == 0

              begin
                snapshot[method_name] = connection.public_send(method_name)
              rescue StandardError
                # Answered per-call through the ordinary dispatch instead.
              end
            end
          end

          # `disable_referential_integrity` wraps a caller block that must run
          # on the worker, so it cannot be dispatched remotely. When the
          # concrete adapter implements it in a standalone module written
          # against the query pipeline (e.g. SQLite3::ReferentialIntegrity),
          # the proxy extends that module and runs it locally instead.
          def referential_integrity_module_name(klass)
            owner = klass.instance_method(:disable_referential_integrity).owner
            owner.name if owner != AbstractAdapter && !owner.is_a?(Class)
          end

          # The computed transport surface for one concrete adapter class:
          # every method the concrete class overrides from AbstractAdapter —
          # instance-level, or class-level behind an instance delegator (e.g.
          # `quote_column_name`) — minus the worker pipeline/lifecycle methods
          # the proxy implements itself.
          def remote_adapter_methods(klass)
            @remote_adapter_methods[klass] ||= begin
              base = AbstractAdapter
              boundary = local_boundary_methods

              instance_candidates = (
                base.instance_methods + base.protected_instance_methods + base.private_instance_methods
              ).uniq
              overridden = instance_candidates.select do |name|
                !boundary.include?(name) &&
                  klass.instance_method(name).owner != base.instance_method(name).owner
              end

              class_candidates = (base.methods + base.protected_methods + base.private_methods).uniq
              class_overridden = class_candidates.select do |name|
                next false if boundary.include?(name)
                next false unless base.method_defined?(name) || base.private_method_defined?(name) ||
                  base.protected_method_defined?(name)
                begin
                  klass.method(name).owner != base.method(name).owner
                rescue NameError
                  false
                end
              end

              ActiveSupport::Ractors.make_shareable((overridden | class_overridden).sort)
            end
          end

          def local_boundary_methods
            @local_boundary_methods ||= (
              RactorConnectionProxy.instance_methods(false) +
              RactorConnectionProxy.protected_instance_methods(false) +
              RactorConnectionProxy.private_instance_methods(false) +
              ALWAYS_LOCAL_METHODS
            ).to_set.freeze
          end
      end

      def initialize(pool, connection_token, profile, config)
        super(nil, PLACEHOLDER_LOGGER, nil, config)
        @connection_token = connection_token
        @logger = nil
        @pool = pool
        @adapter_profile = profile
        @prepared_statements = profile[:prepared_statements]
        @raw_connection = connection_token
        @verified = true
        @remote_capability_memo = {}
        @quoted_column_names = {}
        @quoted_table_names = {}
        @last_query_response = nil
        extend(self.class.remote_dispatch_module(profile))
        # Extended after the dispatch module so its local, pipeline-driven
        # `disable_referential_integrity` shadows the remote (block-refusing)
        # dispatch. Adapters without such a module keep the loud remote error.
        if ri_module_name = profile[:referential_integrity_module_name]
          extend(Object.const_get(ri_module_name))
        end
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
        @verified = true
        self
      end

      def disconnect!
        # Matches AbstractAdapter semantics: closes the physical connection
        # but keeps it leased (token-pinned); the next use reconnects.
        # Returning the token to the pool here would strand the worker-side
        # lease on a dead proxy.
        remote_adapter_call(:disconnect!) if @connection_token
        @verified = false
        reset_transaction
      end

      def discard!
        if token = @connection_token
          @connection_token = nil
          @raw_connection = nil
          self.class.discard_connection(token)
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
          self.class.checkin_connection(token)
        end
      end

      # Backs RactorConnectionPool#remove (AbstractAdapter#throw_away!).
      def remove_connection
        if token = @connection_token
          @connection_token = nil
          @raw_connection = nil
          self.class.remove_connection(token)
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
      # connection (see RactorConnectionProxy.connection_pinned?).
      def holds_main_connection? # :nodoc:
        !!(@connection_token && self.class.connection_pinned?(@connection_token))
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

        copy = !ActiveSupport::Ractors.main?
        self.class.cast_binds_on_connection(
          @connection_token, copy ? self.class.dump_binds(binds) : binds, copy: copy, connection_pool: @pool
        )
      end

      # Mirrors AbstractAdapter#raw_connection against the physical
      # connection: lazily begun worker transactions materialize first and
      # the connection counts as dirty. The raw handle itself can only be
      # held by a main-Ractor caller (self-proxy); a worker caller gets the
      # loud transport error.
      def raw_connection
        materialize_transactions
        disable_lazy_transactions!
        @raw_connection_dirty = true
        remote_adapter_call(:raw_connection)
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

      def to_sql_and_binds(arel_or_sql, binds = [], preparable = nil, allow_retry = false) # :nodoc:
        if arel_or_sql.respond_to?(:ast)
          arel_or_sql = arel_or_sql.ast
        end

        if Arel.arel_node?(arel_or_sql) && !(String === arel_or_sql)
          unless binds.empty?
            raise "Passing bind parameters with an arel AST is forbidden. " \
              "The values must be stored on the AST directly"
          end

          copy = !ActiveSupport::Ractors.main?
          sql, compiled_binds, compiled_preparable, compiled_allow_retry =
            self.class.compile_on_connection(
              @connection_token,
              copy ? self.class.dump_object(arel_or_sql, "an Arel AST") : arel_or_sql,
              preparable,
              allow_retry,
              prepared_statements: prepared_statements?,
              copy: copy,
              connection_pool: @pool,
            )
          [sql, copy ? Marshal.load(compiled_binds) : compiled_binds, compiled_preparable, compiled_allow_retry]
        else
          super
        end
      end

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

      def remote_visitor_compile(node, collector) # :nodoc:
        copy = !ActiveSupport::Ractors.main?
        collector_payload =
          case collector
          when nil
            nil
          when Arel::Collectors::SubstituteBinds
            :substitute_binds
          else
            copy ? self.class.dump_object(collector, "the Arel collector #{collector.class}") : collector
          end

        value, preparable, retryable = self.class.visitor_compile_on_connection(
          @connection_token,
          copy ? self.class.dump_object(node, "an Arel AST") : node,
          collector_payload,
          copy: copy,
          connection_pool: @pool,
        )

        if collector
          collector.preparable = preparable if collector.respond_to?(:preparable=) && !preparable.nil?
          collector.retryable = retryable if collector.respond_to?(:retryable=) && !retryable.nil?
        end
        copy ? Marshal.load(value) : value
      end

      # DDL is rendered by the concrete adapter's SchemaCreation on the main
      # Ractor; the concrete `schema_creation` object itself holds the raw
      # connection and cannot cross the boundary.
      def schema_creation # :nodoc:
        SchemaCreationProxy.new(self)
      end

      # Schema statements only ever run on the main Ractor (migrations,
      # test-suite DDL), so definition rendering refuses worker callers
      # instead of marshaling definition graphs across the boundary.
      def remote_schema_creation_accept(node) # :nodoc:
        unless ActiveSupport::Ractors.main?
          raise ActiveRecordError, "Schema statements can only be executed on the main Ractor"
        end

        self.class.schema_creation_accept_on_connection(@connection_token, node, connection_pool: @pool)
      end

      # See RactorConnectionProxy.begin_transaction_on_connection: the
      # worker-materialized transaction reaches the physical connection
      # through its own TransactionManager, keeping the main side aware of
      # the worker's transaction depth.
      def begin_db_transaction # :nodoc:
        self.class.begin_transaction_on_connection(@connection_token, nil, true, connection_pool: @pool)
      end

      def begin_isolated_db_transaction(isolation) # :nodoc:
        self.class.begin_transaction_on_connection(@connection_token, isolation, true, connection_pool: @pool)
      end

      def begin_deferred_transaction(isolation_level = nil) # :nodoc:
        self.class.begin_transaction_on_connection(@connection_token, isolation_level, false, connection_pool: @pool)
      end

      def commit_db_transaction # :nodoc:
        self.class.commit_transaction_on_connection(@connection_token, connection_pool: @pool)
      end

      def exec_rollback_db_transaction # :nodoc:
        self.class.rollback_transaction_on_connection(@connection_token, connection_pool: @pool)
      end

      def exec_restart_db_transaction # :nodoc:
        remote_adapter_call(:restart_db_transaction)
      end

      private
        def arel_visitor
          VisitorProxy.new(self)
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
          @table_definition_class ||= Object.const_get(@adapter_profile[:table_definition_class_name])
        end

        def adapter_class
          @adapter_class ||= Object.const_get(@adapter_profile[:adapter_class_name])
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
          copy = !ActiveSupport::Ractors.main?
          request = QueryRequest.new(
            sql: intent.processed_sql,
            binds: intent.binds,
            name: intent.name,
            prepare: intent.prepare,
            batch: intent.batch,
            allow_retry: intent.allow_retry,
            copy: copy,
          )

          response = self.class.query_connection(@connection_token, request, connection_pool: @pool)
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
              @remote_capability_memo[method_name] =
                self.class.call_connection(@connection_token, method_name, args, kwargs, connection_pool: @pool)
            end
          else
            self.class.call_connection(@connection_token, method_name, args, kwargs, connection_pool: @pool)
          end
        end

        def method_missing(name, *args, **kwargs, &block)
          return super if name == :marshal_dump || name == :_dump

          if block
            raise ActiveRecordError, "Cannot forward a block to #{name} on the main-Ractor connection"
          end

          # See remote_dispatch_module: remote work must land inside a lazily
          # begun worker-side transaction.
          materialize_transactions unless self.class.pure_remote_method?(name)
          remote_adapter_call(name, args, kwargs)
        end

        def respond_to_missing?(name, include_private = false)
          return false if name == :marshal_dump || name == :_dump

          super
        end
    end
  end
end

ActiveSupport::ForkTracker.after_fork { ActiveRecord::ConnectionAdapters::RactorConnectionProxy.forget_all_connections! }
