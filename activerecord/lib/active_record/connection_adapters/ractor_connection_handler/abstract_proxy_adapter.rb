# frozen_string_literal: true

# :markup: markdown

require "active_record/connection_adapters/ractor_connection_handler"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      class AbstractProxyAdapter < AbstractAdapter # :nodoc:
        autoload :QueryRequest, "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter/query_request"
        autoload :QueryResponse, "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter/query_response"
        autoload :SchemaCreationProxy, "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter/schema_creation_proxy"

        include Proxy

        ADAPTER_NAME = "RactorProxy"
        PLACEHOLDER_LOGGER = Object.new.freeze
        PURE_REMOTE_METHOD_PATTERN = /\A(?:quote|type_to_sql\z|valid_type\?\z|supports_)/
        CAPABILITY_METHOD_PATTERN = /\Asupports_.*\?\z/

        def initialize(pool, connection_token, profile, config)
          @adapter_profile = profile
          super(nil, PLACEHOLDER_LOGGER, nil, config)
          @connection_token = connection_token
          @logger = nil
          @pool = pool
          @prepared_statements = profile[:prepared_statements]
          @main_transaction_manager_id = nil
          @capabilities = profile[:capabilities].dup
          @quoted_column_names = {}
          @quoted_table_names = {}
        end

        def adapter_name
          @adapter_profile[:adapter_name]
        end

        attr_reader :connection_token # :nodoc:

        def connected?
          !!(@connection_token && call_main_connection(:connected?))
        end

        def active?
          !!(@connection_token && call_main_connection(:active?))
        end

        def verify!
          manage_main_connection(:verify!)
          self
        end

        def connect!
          manage_main_connection(:connect!)
          self
        end

        def reconnect!(restore_transactions: false)
          manage_main_connection(:reconnect!, restore_transactions: restore_transactions)
          self
        end

        def disconnect!
          # Disconnect the physical connection while maintaining the lease of that same instance.
          if @connection_token
            manage_main_connection(:disconnect!)
          else
            reset_transaction
          end
        end

        def discard!
          if token = @connection_token
            @connection_token = nil
            discard_token(token)
          end
          reset_transaction
        end

        def reset!
          manage_main_connection(:reset!)
          self
        end

        def reset_transaction(...) # :nodoc:
          @main_transaction_manager_id = nil
          super
        end

        def release_connection
          if token = @connection_token
            @connection_token = nil
            checkin_token(token)
          end
        end

        def remove_connection
          if token = @connection_token
            @connection_token = nil
            remove_token(token)
          end
        end

        def clear_cache!(new_connection: false)
          super
          remote_adapter_call(:clear_cache!, [], { new_connection: new_connection }) if @connection_token
        end

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
            fetch_connection(token).type_casted_binds(Marshal.load(binds_payload))
          end
        end

        def raw_connection
          unless ActiveSupport::Ractors.main?
            raise ActiveRecordError, "The raw connection of a Ractor-proxied connection can only be accessed from the main Ractor"
          end
          unless @connection_token
            raise ConnectionNotEstablished, "The Ractor-pinned connection has been released"
          end

          disable_lazy_transactions!
          Proxy.fetch_transaction_connection(@connection_token, @main_transaction_manager_id).raw_connection
        end

        # Checkout/checkin callbacks are class-level state that is not Ractor-shareable;
        # the concrete adapter runs them main-side when the connection returns to its pool.
        def run_callbacks(kind, &block) # :nodoc:
          if kind == :checkin || kind == :checkout
            block ? yield : nil
          else
            super
          end
        end

        def columns(...)
          remote_dispatch(:columns, ...)
        end

        def data_sources
          remote_dispatch(:data_sources)
        end

        def data_source_exists?(...)
          remote_dispatch(:data_source_exists?, ...)
        end

        def indexes(...)
          remote_dispatch(:indexes, ...)
        end

        def primary_key(...)
          remote_dispatch(:primary_key, ...)
        end

        def schema_creation # :nodoc:
          SchemaCreationProxy.new(self)
        end

        def remote_schema_creation_accept(node) # :nodoc:
          raise ActiveRecordError, "Schema statements can only be executed on the main Ractor"
        end

        def build_insert_sql(insert) # :nodoc:
          raise ActiveRecordError, "insert_all/upsert_all can only be executed on the main Ractor"
        end

        def execute(...)
          cast_result(super)
        end

        def _exec_insert(intent, sequence_name = nil, returning: nil) # :nodoc:
          apply_returning_to!(intent, returning)
          intent.execute!
          intent.raw_result
        end

        def begin_db_transaction # :nodoc:
          begin_main_transaction(nil, true)
        end

        def begin_isolated_db_transaction(isolation) # :nodoc:
          begin_main_transaction(isolation, true)
        end

        def begin_deferred_transaction(isolation_level = nil) # :nodoc:
          begin_main_transaction(isolation_level, false)
        end

        def commit_db_transaction # :nodoc:
          commit_main_transaction
        ensure
          # Main-side transaction is gone, even if the commit failed
          @main_transaction_manager_id = nil
        end

        def exec_rollback_db_transaction # :nodoc:
          # Already gone if this follows a failed commit
          rollback_main_transaction if @main_transaction_manager_id
        ensure
          @main_transaction_manager_id = nil
        end

        def begin_savepoint_transaction(name) # :nodoc:
          main_transaction_operation(@main_transaction_manager_id) do |connection|
            connection.begin_transaction(_lazy: false)
            nil
          end
        end

        def commit_savepoint_transaction(name) # :nodoc:
          commit_main_transaction
        end

        def rollback_savepoint_transaction(name) # :nodoc:
          depth = current_transaction.savepoint_name == name ? open_transactions : open_transactions + 1
          rollback_main_transaction(depth)
        end

        def restart_parent_transactions? # :nodoc:
          false
        end

        # Regardless of whether the main-side connection invalidates its own
        # transaction, we need the rollback to keep us in sync.
        def savepoint_errors_invalidate_transactions? # :nodoc:
          false
        end

        private
          def ensure_connection_ready(allow_retry:, materialize_transactions:)
            self.materialize_transactions if materialize_transactions
            false
          end

          def build_retry_budget(allow_retry:, reconnectable:)
            super(allow_retry: false, reconnectable: false)
          end

          def arel_visitor
            @adapter_profile[:arel_visitor_class].new(self)
          end

          def bind_params_length
            @adapter_profile[:bind_params_length]
          end

          def create_table_definition(name, **options)
            table_definition_class.new(self, name, **options)
          end

          def table_definition_class
            @adapter_profile[:table_definition_class]
          end

          def adapter_class
            @adapter_profile[:adapter_class]
          end

          # Local casting must match the concrete adapter (e.g. SQLite3's integer limit).
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
              materialize_transactions: intent.materialize_transactions,
            )

            token = @connection_token
            transaction_manager_id = @main_transaction_manager_id if intent.materialize_transactions
            response = main_operation(connection_pool: @pool) do
              request.perform(fetch_transaction_connection(token, transaction_manager_id))
            end
            intent.notification_payload[:affected_rows] = response.affected_rows
            intent.notification_payload[:row_count] = response.row_count
            response
          end

          def cast_result(response)
            ActiveRecord::Result.new(response.columns, response.rows, response.column_types, affected_rows: response.affected_rows)
          end

          def affected_rows(response)
            response.affected_rows
          end

          def collect_warnings(response)
            response&.warnings
          end

          def last_inserted_id(response)
            response.last_inserted_id
          end

          # A lazily begun worker transaction must reach the main connection before
          # remote work that may write through it (e.g. SQLite3#add_column).
          def remote_dispatch(method_name, *args, **kwargs, &block)
            if block
              raise ActiveRecordError, "Cannot forward a block to #{method_name} on the main-Ractor connection"
            end

            materialize_transactions
            remote_adapter_call(method_name, args, kwargs, transaction_manager_id: @main_transaction_manager_id)
          end

          def pure_remote_dispatch(method_name, *args, **kwargs, &block)
            if block
              raise ActiveRecordError, "Cannot forward a block to #{method_name} on the main-Ractor connection"
            end

            remote_adapter_call(method_name, args, kwargs)
          end

          def remote_adapter_call(method_name, args = [], kwargs = {}, transaction_manager_id: nil)
            if args.empty? && kwargs.empty? && CAPABILITY_METHOD_PATTERN.match?(method_name)
              @capabilities.fetch(method_name) do
                @capabilities[method_name] = call_main_connection(method_name, args, kwargs)
              end
            else
              call_main_connection(method_name, args, kwargs, transaction_manager_id: transaction_manager_id)
            end
          end

          def call_main_connection(method_name, args = [], kwargs = {}, transaction_manager_id: nil)
            main_args = ActiveSupport::Ractors.make_shareable(args)
            main_kwargs = ActiveSupport::Ractors.make_shareable(kwargs)

            main_transaction_operation(transaction_manager_id) do |connection|
              connection.__send__(method_name, *main_args, **main_kwargs)
            end
          end

          # Yields the main-side connection on the main Ractor, first checking it
          # still has the transaction manager identified by
          # `transaction_manager_id`, if given.
          def main_transaction_operation(transaction_manager_id, &block)
            unless token = @connection_token
              raise ConnectionNotEstablished, "The Ractor-pinned connection has been released"
            end

            operation = ActiveSupport::Ractors.shareable_proc(self: nil, &block)
            main_operation(connection_pool: @pool) do
              operation.call(fetch_transaction_connection(token, transaction_manager_id))
            end
          end

          # The main-side connection replaces its transaction manager whenever it
          # resets its transactions without restoring them, so we record its
          # identity to later notice if we get out of sync.
          def begin_main_transaction(isolation, joinable)
            @main_transaction_manager_id = main_transaction_operation(nil) do |connection|
              connection.begin_transaction(isolation: isolation, joinable: joinable, _lazy: false)
              connection.transaction_manager.object_id
            end
          end

          def commit_main_transaction
            transaction_manager_id = @main_transaction_manager_id
            main_transaction_operation(nil) do |connection|
              unless connection.transaction_manager.object_id == transaction_manager_id
                raise ConnectionNotEstablished, "Cannot commit: the Ractor-pinned connection was reset while the transaction was open, and the server rolled it back"
              end

              transaction = connection.current_transaction
              begin
                connection.commit_transaction
              rescue ConnectionFailed
                # The transaction has already gone with the connection, so there's
                # nothing to roll back.
                raise
              rescue Exception
                connection.rollback_transaction(transaction) unless transaction.state.completed?
                raise
              end
              nil
            end
          end

          def rollback_main_transaction(depth = nil)
            transaction_manager_id = @main_transaction_manager_id
            main_transaction_operation(nil) do |connection|
              if connection.transaction_manager.object_id == transaction_manager_id && (depth.nil? || connection.open_transactions == depth)
                connection.rollback_transaction
              end
              nil
            end
          end

          # Runs a connection management method on the main-side connection. If
          # we notice that the main transaction manager has been replaced, we
          # reset ours to match.
          def manage_main_connection(method_name, **kwargs)
            main_kwargs = ActiveSupport::Ractors.make_shareable(kwargs)
            transaction_manager_id = @main_transaction_manager_id
            kept = main_transaction_operation(nil) do |connection|
              transaction_manager = connection.transaction_manager
              connection.public_send(method_name, **main_kwargs)
              connection.transaction_manager.equal?(transaction_manager) &&
                (transaction_manager_id.nil? || transaction_manager.object_id == transaction_manager_id)
            end
            reset_transaction unless kept
          end

          def method_missing(name, *args, **kwargs, &block)
            return super if name == :marshal_dump || name == :_dump

            if block
              raise ActiveRecordError, "Cannot forward a block to #{name} on the main-Ractor connection"
            end

            if PURE_REMOTE_METHOD_PATTERN.match?(name)
              remote_adapter_call(name, args, kwargs)
            else
              materialize_transactions
              remote_adapter_call(name, args, kwargs, transaction_manager_id: @main_transaction_manager_id)
            end
          end

          def respond_to_missing?(name, include_private = false)
            return false if name == :marshal_dump || name == :_dump

            super
          end
      end
    end
  end
end
