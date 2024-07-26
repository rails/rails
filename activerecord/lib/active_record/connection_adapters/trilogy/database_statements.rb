# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogy
      module DatabaseStatements
        def exec_insert(sql, name, binds, pk = nil, sequence_name = nil, returning: nil) # :nodoc:
          sql, _binds = sql_for_insert(sql, pk, binds, returning)
          internal_execute(sql, name)
        end

        private
          def raw_execute(sql, name, binds = nil, prepare: false, async: false, allow_retry: false, materialize_transactions: true)
            log(sql, name, async: async) do |notification_payload|
              with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
                sync_timezone_changes(conn)
                result = conn.query(sql)
                while conn.more_results_exist?
                  conn.next_result
                end
                verified!
                handle_warnings(sql)
                notification_payload[:row_count] = result.count
                result
              end
            end
          end

          def cast_result(result)
            if result.count.zero?
              ActiveRecord::Result.empty
            else
              ActiveRecord::Result.new(result.fields, result.rows)
            end
          end

          def affected_rows(result)
            result.affected_rows
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
            combine_multi_statements(statements).each do |statement|
              with_raw_connection do |conn|
                raw_execute(statement, name)
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
