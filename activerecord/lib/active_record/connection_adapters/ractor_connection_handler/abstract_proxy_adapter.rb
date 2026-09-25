# frozen_string_literal: true

# :markup: markdown

require "active_record/connection_adapters/ractor_connection_handler"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandler # :nodoc:
      class AbstractProxyAdapter < AbstractAdapter # :nodoc:
        autoload :QueryRequest, "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter/query_request"
        autoload :QueryResponse, "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter/query_response"
        autoload :Result, "active_record/connection_adapters/ractor_connection_handler/abstract_proxy_adapter/result"
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
          @raw_connection = connection_token
          @verified = true
          @capabilities = profile[:capabilities].dup
          @quoted_column_names = {}
          @quoted_table_names = {}
        end

        def adapter_name
          @adapter_profile[:adapter_name]
        end

        attr_reader :connection_token # :nodoc:

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
          # Transaction state is worker-owned, so the physical connection must not restore by itself.
          remote_adapter_call(:reconnect!, [], { restore_transactions: false })
          reset_transaction(restore: restore_transactions) { }
          @needs_reconnect = false
          @verified = true
          self
        end

        def disconnect!
          # Disconnect the physical connection while maintaining the lease of that same instance.
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

        def remove_connection
          if token = @connection_token
            @connection_token = nil
            @raw_connection = nil
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

          materialize_transactions
          disable_lazy_transactions!
          @raw_connection_dirty = true
          Proxy.fetch_connection(@connection_token).raw_connection
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

        def schema_creation # :nodoc:
          SchemaCreationProxy.new(self)
        end

        def remote_schema_creation_accept(node) # :nodoc:
          raise ActiveRecordError, "Schema statements can only be executed on the main Ractor"
        end

        def build_insert_sql(insert) # :nodoc:
          raise ActiveRecordError, "insert_all/upsert_all can only be executed on the main Ractor"
        end

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
            )

            token = @connection_token
            response = main_operation(connection_pool: @pool) do
              request.perform(fetch_connection(token))
            end
            intent.notification_payload[:affected_rows] = response.affected_rows
            intent.notification_payload[:row_count] = response.row_count
            response.to_result
          end

          def cast_result(result)
            result
          end

          def affected_rows(result)
            result.affected_rows
          end

          def collect_warnings(result)
            result&.warnings
          end

          def last_inserted_id(result)
            result.last_inserted_id
          end

          # A lazily begun worker transaction must reach the main connection before
          # remote work that may write through it (e.g. SQLite3#add_column).
          def remote_dispatch(method_name, *args, **kwargs, &block)
            if block
              raise ActiveRecordError, "Cannot forward a block to #{method_name} on the main-Ractor connection"
            end

            materialize_transactions
            remote_adapter_call(method_name, args, kwargs)
          end

          def pure_remote_dispatch(method_name, *args, **kwargs, &block)
            if block
              raise ActiveRecordError, "Cannot forward a block to #{method_name} on the main-Ractor connection"
            end

            remote_adapter_call(method_name, args, kwargs)
          end

          def remote_adapter_call(method_name, args = [], kwargs = {})
            if args.empty? && kwargs.empty? && CAPABILITY_METHOD_PATTERN.match?(method_name)
              @capabilities.fetch(method_name) do
                @capabilities[method_name] = call_main_connection(method_name, args, kwargs)
              end
            else
              call_main_connection(method_name, args, kwargs)
            end
          end

          def call_main_connection(method_name, args, kwargs)
            unless token = @connection_token
              raise ConnectionNotEstablished, "The Ractor-pinned connection has been released"
            end

            main_args = ActiveSupport::Ractors.make_shareable(args)
            main_kwargs = ActiveSupport::Ractors.make_shareable(kwargs)

            main_operation(connection_pool: @pool) do
              fetch_connection(token).__send__(method_name, *main_args, **main_kwargs)
            end
          end

          # Crosses at the TransactionManager level so the connection's own manager
          # tracks the worker's depth.
          def begin_main_transaction(isolation, joinable)
            token = @connection_token
            main_operation(connection_pool: @pool) do
              fetch_connection(token).begin_transaction(isolation: isolation, joinable: joinable, _lazy: false)
              nil
            end
          end

          def commit_main_transaction
            token = @connection_token
            main_operation(connection_pool: @pool) do
              connection = fetch_connection(token)
              unless connection.transaction_open?
                raise ConnectionNotEstablished, "Cannot commit: the Ractor-pinned connection was reset while the transaction was open, and the server rolled it back"
              end
              connection.commit_transaction
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
