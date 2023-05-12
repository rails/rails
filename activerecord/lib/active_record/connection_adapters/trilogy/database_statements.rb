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

        def exec_query(sql, name = "SQL", binds = [], prepare: false, async: false) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)

          result = raw_execute(sql, name, async: async)
          ActiveRecord::Result.new(result.fields, result.to_a)
        end

        def exec_insert(sql, name, binds, pk = nil, sequence_name = nil) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)

          raw_execute(to_sql(sql, binds), name)
        end

        def exec_delete(sql, name = nil, binds = []) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)

          result = raw_execute(to_sql(sql, binds), name)
          result.affected_rows
        end

        alias :exec_update :exec_delete # :nodoc:

        private
          def last_inserted_id(result)
            result.last_insert_id
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
              conn.set_server_option(::Trilogy::SET_SERVER_MULTI_STATEMENTS_OFF)
            end
          end
      end
    end
  end
end
