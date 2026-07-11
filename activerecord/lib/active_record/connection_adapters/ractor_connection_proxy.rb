# frozen_string_literal: true

# :markup: markdown

require "ractor/dispatch"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionProxy < AbstractAdapter # :nodoc:
      ADAPTER_NAME = "RactorProxy"

      @connections = {}.compare_by_identity
      @next_connection_id = 0

      class VisitorProxy
        class << self
          def compile(node, collector = nil)
            node_data = Marshal.dump(node).freeze
            if collector
              collector_retryable = collector.retryable if collector.respond_to?(:retryable)
              collector_preparable = collector.preparable if collector.respond_to?(:preparable)
              result, preparable, retryable = ActiveSupport::Ractors.on_main do
                n = Marshal.load(node_data)
                ActiveRecord::Base.with_connection do |c|
                  col = c.send(:collector)
                  col.retryable = collector_retryable if col.respond_to?(:retryable=) && !collector_retryable.nil?
                  col.preparable = collector_preparable if col.respond_to?(:preparable=) && !collector_preparable.nil?

                  compiled = c.visitor.compile(n, col)
                  if compiled.is_a?(Array)
                    sql, binds = compiled
                    compiled = [sql, c.type_casted_binds(binds)]
                  end

                  [RactorConnectionProxy.shareable_copy(compiled), (col.preparable if col.respond_to?(:preparable)), (col.retryable if col.respond_to?(:retryable))]
                end
              end
              collector.preparable = preparable if collector.respond_to?(:preparable=) && !preparable.nil?
              collector.retryable = retryable if collector.respond_to?(:retryable=) && !retryable.nil?
              result
            else
              ActiveSupport::Ractors.on_main do
                n = Marshal.load(node_data)
                ActiveRecord::Base.with_connection { |c| c.visitor.compile(n) }.freeze
              end
            end
          end

          def accept(node, collector = nil)
            node_data = Marshal.dump(node).freeze
            # The collector (Arel::Collectors::SQLString) can't cross the
            # Ractor boundary. Create a fresh one in the main Ractor.
            ActiveSupport::Ractors.on_main do
              n = Marshal.load(node_data)
              ActiveRecord::Base.with_connection do |c|
                col = Arel::Collectors::SQLString.new
                c.visitor.accept(n, col)
              end
            end
          end
        end
      end

      class QueryRequest
        attr_reader :sql, :binds, :name, :prepare, :batch, :allow_retry

        def initialize(sql:, binds:, name:, prepare:, batch:, allow_retry:)
          @sql = RactorConnectionProxy.shareable_copy(sql)
          @binds = RactorConnectionProxy.shareable_copy(binds)
          @name = RactorConnectionProxy.shareable_copy(name || "SQL")
          @prepare = prepare
          @batch = batch
          @allow_retry = allow_retry
          ActiveSupport::Ractors.make_shareable(self)
        end
      end

      class QueryResponse
        attr_reader :columns, :rows, :column_types, :affected_rows

        def initialize(result)
          @columns = RactorConnectionProxy.shareable_copy(result.columns)
          @rows = RactorConnectionProxy.shareable_copy(result.rows)
          @column_types = {}.freeze
          @affected_rows = result.affected_rows
          ActiveSupport::Ractors.make_shareable(self)
        end

        def to_result
          ActiveRecord::Result.new(@columns, @rows, @column_types, affected_rows: @affected_rows)
        end
      end

      class Error
        attr_reader :error_class_name, :message

        def initialize(error_class_name, message)
          @error_class_name = error_class_name
          @message = message
          ActiveSupport::Ractors.make_shareable(self)
        end
      end

      class << self
        def checkout_main_connection(connection_name, role, shard)
          shareable_connection_name = shareable_copy(connection_name.to_s)
          ActiveSupport::Ractors.on_main do
            pool = RactorConnectionProxy.main_pool(shareable_connection_name, role, shard)
            connection_id = RactorConnectionProxy.next_connection_id
            RactorConnectionProxy.connections[connection_id] = pool.checkout
            connection_id
          end
        end

        def next_connection_id
          @next_connection_id += 1
        end

        attr_reader :connections

        def checkin_main_connection(connection_token)
          ActiveSupport::Ractors.on_main do
            if connection = RactorConnectionProxy.connections.delete(connection_token)
              connection.pool.checkin(connection)
            end
            nil
          end
        end

        def checkin_all_connections
          ActiveSupport::Ractors.on_main do
            RactorConnectionProxy.connections.each_value do |connection|
              connection.pool.checkin(connection)
            end
            RactorConnectionProxy.connections.clear
            nil
          end
        end

        def main_pool_specs(role = nil)
          ActiveSupport::Ractors.on_main do
            RactorConnectionProxy.main_connection_handler.connection_pool_list(role).map do |pool|
              RactorConnectionPool.spec_for(pool)
            end
          end
        end

        def main_pool_spec(connection_name, role, shard, strict)
          shareable_connection_name = shareable_copy(connection_name.to_s)
          ActiveSupport::Ractors.on_main do
            pool = RactorConnectionProxy.main_connection_handler.retrieve_connection_pool(
              shareable_connection_name,
              role: role,
              shard: shard,
              strict: strict,
            )
            pool && RactorConnectionPool.spec_for(pool)
          end
        end

        def dispatch_to_main_pool(connection_name, role, shard, method_name, args, kwargs)
          shareable_connection_name = shareable_copy(connection_name.to_s)
          shareable_args = shareable_copy(args)
          shareable_kwargs = shareable_copy(kwargs)
          dispatched_method = method_name.to_sym

          ActiveSupport::Ractors.on_main do
            result = RactorConnectionProxy.main_pool(shareable_connection_name, role, shard).__send__(dispatched_method, *shareable_args, **shareable_kwargs)
            RactorConnectionProxy.shareable_copy(result)
          end
        end

        def dispatch_to_main_connection(connection_token, method_name, args = [], kwargs = {})
          shareable_args = shareable_copy(args)
          shareable_kwargs = shareable_copy(kwargs)
          dispatched_method = method_name.to_sym

          outcome = ActiveSupport::Ractors.on_main do
            connection = RactorConnectionProxy.connections.fetch(connection_token)
            begin
              RactorConnectionProxy.shareable_copy(connection.__send__(dispatched_method, *shareable_args, **shareable_kwargs))
            rescue => e
              RactorConnectionProxy.error(e)
            end
          end
          unwrap_outcome(outcome)
        end

        def dispatch_query(connection_token, request)
          outcome = ActiveSupport::Ractors.on_main do
            connection = RactorConnectionProxy.connections.fetch(connection_token)
            begin
              result = if request.batch
                connection.execute(request.sql, request.name, allow_retry: request.allow_retry)
              elsif request.prepare
                connection.exec_query(request.sql, request.name, request.binds, prepare: true)
              else
                connection.exec_query(request.sql, request.name, request.binds)
              end

              QueryResponse.new(result)
            rescue => e
              RactorConnectionProxy.error(e)
            end
          end
          unwrap_outcome(outcome)
        end

        def error(e)
          Error.new(e.class.name.to_s, e.message.to_s)
        end

        def unwrap_outcome(outcome)
          raise RuntimeError, outcome.message if outcome.is_a?(Error)

          outcome
        end

        def shareable_copy(value)
          return value if ActiveSupport::Ractors.shareable?(value)

          copy = Marshal.load(Marshal.dump(value))
          ActiveSupport::Ractors.make_shareable(copy)
        end

        def main_connection_handler
          ActiveRecord::Base.connection_handler
        end

        def main_pool(connection_name, role, shard)
          main_connection_handler.retrieve_connection_pool(
            connection_name,
            role: role,
            shard: shard,
            strict: true,
          )
        end
      end

      DELEGATED_METHODS = %i[
        adapter_name native_database_types get_database_version database_version
        quote quote_string quote_column_name quote_table_name quote_table_name_for_assignment
        quoted_true quoted_false unquoted_true unquoted_false quote_default_expression
        lookup_cast_type type_to_sql build_insert_sql default_sequence_name empty_insert_statement_value
        supports_advisory_locks? supports_bulk_alter? supports_check_constraints?
        supports_comments? supports_comments_in_create? supports_common_table_expressions?
        supports_concurrent_connections? supports_datetime_with_precision?
        supports_ddl_transactions? supports_deferrable_constraints? supports_disabling_indexes?
        supports_exclusion_constraints? supports_explain? supports_expression_index?
        supports_extensions? supports_foreign_keys? supports_identity_columns?
        supports_index_include? supports_index_sort_order? supports_index_using?
        supports_indexes_in_create? supports_insert_on_conflict?
        supports_insert_on_duplicate_skip? supports_insert_on_duplicate_update?
        supports_insert_raw_alias_syntax? supports_insert_returning? supports_json?
        supports_lazy_transactions? supports_materialized_views? supports_native_partitioning?
        supports_nulls_not_distinct? supports_optimizer_hints? supports_partial_index?
        supports_partitioned_indexes? supports_rename_column? supports_rename_index?
        supports_restart_db_transaction? supports_savepoints? supports_transaction_isolation?
        supports_unique_constraints? supports_validate_constraints? supports_views?
        supports_virtual_columns?
      ].freeze

      DELEGATED_METHODS.each do |method_name|
        delegated_method_name = method_name
        define_method(delegated_method_name,
          ActiveSupport::Ractors.make_shareable(
            ->(*args, **kwargs) {
              self.class.dispatch_to_main_connection(@main_connection_token, delegated_method_name, args, kwargs)
            },
            copy: false
          ))
      end

      PLACEHOLDER_LOGGER = Object.new.freeze
      def initialize(pool, main_connection_token, config)
        super(nil, PLACEHOLDER_LOGGER, nil, config)
        @logger = nil
        @pool = pool
        @main_connection_token = main_connection_token.freeze
        @raw_connection = @main_connection_token
        @verified = true
      end

      def connected?
        @raw_connection.present?
      end

      def active?
        connected?
      end

      def verify!
        @verified = true
        self
      end

      def reconnect!
        verify!
      end

      def disconnect!
        release_main_connection
      end

      def release_main_connection
        self.class.checkin_main_connection(@main_connection_token) if @main_connection_token
        @main_connection_token = nil
        @raw_connection = nil
      end

      def begin_db_transaction
        self.class.dispatch_to_main_connection(@main_connection_token, __method__)
      end

      def begin_isolated_db_transaction(isolation)
        self.class.dispatch_to_main_connection(@main_connection_token, __method__, [isolation])
      end

      def commit_db_transaction
        self.class.dispatch_to_main_connection(@main_connection_token, __method__)
      end

      def exec_rollback_db_transaction
        self.class.dispatch_to_main_connection(@main_connection_token, __method__)
      end

      def restart_db_transaction
        self.class.dispatch_to_main_connection(@main_connection_token, __method__)
      end

      def reset_isolation_level
        self.class.dispatch_to_main_connection(@main_connection_token, __method__)
      end

      def last_inserted_id(result)
        result.rows.dig(0, 0)
      end

      def returning_column_values(result)
        result.rows.first || []
      end

      def method_missing(name, *args, **kwargs, &block)
        return super if block || name == :marshal_dump || name == :_dump

        self.class.dispatch_to_main_connection(@main_connection_token, name, args, kwargs)
      end

      def respond_to_missing?(name, include_private = false)
        return false if name == :marshal_dump || name == :_dump

        super
      end

      private
        def arel_visitor
          VisitorProxy
        end

        def cast_result(result)
          result
        end

        def affected_rows(result)
          result.affected_rows
        end

        def ractor_query_binds(intent)
          intent.type_casted_binds
        rescue Ractor::Error, RuntimeError
          intent.binds
        end

        def perform_query(_raw_connection, intent)
          request = QueryRequest.new(
            sql: intent.processed_sql,
            binds: ractor_query_binds(intent),
            name: intent.name || "SQL",
            prepare: intent.prepare,
            batch: intent.batch,
            allow_retry: intent.allow_retry,
          )

          response = self.class.dispatch_query(@main_connection_token, request)
          result = response.to_result
          intent.notification_payload[:affected_rows] = result.affected_rows
          intent.notification_payload[:row_count] = result.length
          result
        end
    end
  end
end
