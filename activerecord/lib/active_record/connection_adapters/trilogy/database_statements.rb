# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogy
      module DatabaseStatements
        def _exec_insert(intent, pk = nil, sequence_name = nil, returning: nil) # :nodoc:
          sql, binds = sql_for_insert(intent.raw_sql, pk, intent.binds, returning)
          intent.raw_sql = sql
          intent.binds = binds

          # AbstractAdapter calls raw_exec_query (returning an AR::Result), but
          # our last_inserted_id needs the raw Trilogy result object
          raw_execute(intent)
        end

        private
          def perform_query(raw_connection, intent)
            reset_multi_statement = if intent.batch && !@config[:multi_statement]
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

            result = raw_connection.query(intent.processed_sql)
            while raw_connection.more_results_exist?
              raw_connection.next_result
            end
            verified!

            intent.notification_payload[:affected_rows] = result.affected_rows
            intent.notification_payload[:row_count] = result.count
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
              intent = QueryIntent.new(
                processed_sql: statement,
                name: name,
                batch: true,
                binds: kwargs[:binds] || [],
                prepare: kwargs[:prepare] || false,
                async: kwargs[:async] || false,
                allow_retry: kwargs[:allow_retry] || false,
                materialize_transactions: kwargs[:materialize_transactions] != false
              )
              raw_execute(intent)
            end
          end
      end
    end
  end
end
