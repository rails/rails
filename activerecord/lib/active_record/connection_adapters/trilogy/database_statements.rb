# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogy
      module DatabaseStatements
        def select_all(*, **) # :nodoc:
          result = super
          with_raw_connection do |conn|
            conn.next_result while conn.more_results_exist?
          end
          result
        end

        def internal_exec_query(sql, name = "SQL", binds = [], prepare: false, async: false) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)
          mark_transaction_written_if_write(sql)

          result = raw_execute(sql, name, async: async)
          ActiveRecord::Result.new(result.fields, result.to_a)
        end

        def exec_insert(sql, name, binds, pk = nil, sequence_name = nil, returning: nil) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)
          mark_transaction_written_if_write(sql)

          sql, _binds = sql_for_insert(sql, pk, binds, returning)
          raw_execute(sql, name)
        end

        def exec_delete(sql, name = nil, binds = []) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)
          mark_transaction_written_if_write(sql)

          result = raw_execute(to_sql(sql, binds), name)
          result.affected_rows
        end

        alias :exec_update :exec_delete # :nodoc:

        private
          def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
            log(sql, name, async: async) do |notification_payload|
              with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
                sync_timezone_changes(conn)
                result = with_transient_conn_properties(conn) do
                  conn.query(sql)
                end
                verified!
                handle_warnings(sql)
                notification_payload[:row_count] = result.count
                result
              end
            end
          end

          def with_transient_conn_properties(conn)
            return yield(conn) unless custom_conn_properties?

            original_read_timeout = conn.read_timeout
            original_write_timeout = conn.write_timeout
            original_query_flags = conn.query_flags

            read_timeout, write_timeout, query_flags = custom_conn_properties

            conn.read_timeout = read_timeout || original_read_timeout
            conn.write_timeout = write_timeout || original_write_timeout
            conn.query_flags = query_flags || original_query_flags

            result = yield(conn)

            conn.read_timeout = original_read_timeout
            conn.write_timeout = original_write_timeout
            conn.query_flags = original_query_flags

            result
          end

          def custom_conn_properties?
            !!ActiveSupport::IsolatedExecutionState[:active_record_custom_conn_properties]
          end

          def custom_conn_properties
            read_timeout, write_timeout, query_flags = ActiveSupport::IsolatedExecutionState[:active_record_custom_conn_properties]

            read_timeout = if read_timeout.respond_to?(:call)
              read_timeout.call
            else
              read_timeout
            end

            write_timeout = if write_timeout.respond_to?(:call)
              write_timeout.call
            else
              write_timeout
            end

            query_flags = if query_flags.respond_to?(:call)
              query_flags.call
            else
              query_flags
            end

            [read_timeout, write_timeout, query_flags]
          end

          def last_inserted_id(result)
            if supports_insert_returning?
              super
            else
              result.last_insert_id
            end
          end

          def sync_timezone_changes(conn)
            # Sync any changes since connection last established.
            if default_timezone == :local
              conn.query_flags |= ::Trilogy::QUERY_FLAGS_LOCAL_TIMEZONE
            else
              conn.query_flags &= ~::Trilogy::QUERY_FLAGS_LOCAL_TIMEZONE
            end
          end

          def execute_batch(statements, name = nil)
            statements = statements.map { |sql| transform_query(sql) }
            combine_multi_statements(statements).each do |statement|
              with_raw_connection do |conn|
                raw_execute(statement, name)
                conn.next_result while conn.more_results_exist?
              end
            end
          end

          def multi_statements_enabled?
            !!@config[:multi_statement]
          end

          def with_multi_statements
            if multi_statements_enabled?
              return yield
            end

            with_raw_connection do |conn|
              conn.set_server_option(::Trilogy::SET_SERVER_MULTI_STATEMENTS_ON)

              yield
            ensure
              conn.set_server_option(::Trilogy::SET_SERVER_MULTI_STATEMENTS_OFF) if active?
            end
          end
      end
    end
  end
end
