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
          def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch: false)
            reset_multi_statement = if batch && !@config[:multi_statement]
              raw_connection.set_server_option(::Trilogy::SET_SERVER_MULTI_STATEMENTS_ON)
              true
            end

            # Make sure we carry over any changes to ActiveRecord.default_timezone that have been
            # made since we established the connection
            if default_timezone == :local
              raw_connection.query_flags |= ::Trilogy::QUERY_FLAGS_LOCAL_TIMEZONE
            else
              raw_connection.query_flags &= ~::Trilogy::QUERY_FLAGS_LOCAL_TIMEZONE
            end

            result = raw_connection.query(sql)
            while raw_connection.more_results_exist?
              raw_connection.next_result
            end
            verified!

            notification_payload[:affected_rows] = result.affected_rows
            notification_payload[:row_count] = result.count
            result
          ensure
            if reset_multi_statement && active?
              raw_connection.set_server_option(::Trilogy::SET_SERVER_MULTI_STATEMENTS_OFF)
            end
          end

          def cast_result(result)
            if result.fields.empty?
              ActiveRecord::Result.empty(affected_rows: result.affected_rows)
            else
              ActiveRecord::Result.new(result.fields, result.rows, affected_rows: result.affected_rows)
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

          def execute_batch(statements, name = nil, **kwargs)
            combine_multi_statements(statements).each do |statement|
              raw_execute(statement, name, batch: true, **kwargs)
            end
          end
      end
    end
  end
end
