# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2
      module DatabaseStatements
        # Returns an ActiveRecord::Result instance.
        def select_all(*, **) # :nodoc:
          result = nil
          with_raw_connection do |conn|
            result = if ExplainRegistry.collect? && prepared_statements
              unprepared_statement { super }
            else
              super
            end
            conn.abandon_results!
          end
          result
        end

        def internal_exec_query(sql, name = "SQL", binds = [], prepare: false, async: false) # :nodoc:
          if without_prepared_statement?(binds)
            execute_and_free(sql, name, async: async) do |result|
              if result
                build_result(columns: result.fields, rows: result.to_a)
              else
                build_result(columns: [], rows: [])
              end
            end
          else
            exec_stmt_and_free(sql, name, binds, cache_stmt: prepare, async: async) do |_, result|
              if result
                build_result(columns: result.fields, rows: result.to_a)
              else
                build_result(columns: [], rows: [])
              end
            end
          end
        end

        def exec_delete(sql, name = nil, binds = []) # :nodoc:
          if without_prepared_statement?(binds)
            with_raw_connection do |conn|
              @affected_rows_before_warnings = nil
              execute_and_free(sql, name) { @affected_rows_before_warnings || conn.affected_rows }
            end
          else
            exec_stmt_and_free(sql, name, binds) { |stmt| stmt.affected_rows }
          end
        end
        alias :exec_update :exec_delete

        private
          def sync_timezone_changes(raw_connection)
            raw_connection.query_options[:database_timezone] = default_timezone
          end

          def execute_batch(statements, name = nil)
            statements = statements.map { |sql| transform_query(sql) }
            combine_multi_statements(statements).each do |statement|
              with_raw_connection do |conn|
                raw_execute(statement, name)
                conn.abandon_results!
              end
            end
          end

          def last_inserted_id(result)
            @raw_connection&.last_id
          end

          def multi_statements_enabled?
            flags = @config[:flags]

            if flags.is_a?(Array)
              flags.include?("MULTI_STATEMENTS")
            else
              flags.anybits?(::Mysql2::Client::MULTI_STATEMENTS)
            end
          end

          def with_multi_statements
            if multi_statements_enabled?
              return yield
            end

            with_raw_connection do |conn|
              conn.set_server_option(::Mysql2::Client::OPTION_MULTI_STATEMENTS_ON)

              yield
            ensure
              conn.set_server_option(::Mysql2::Client::OPTION_MULTI_STATEMENTS_OFF)
            end
          end

          def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
            log(sql, name, async: async) do
              with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
                sync_timezone_changes(conn)
                result = conn.query(sql)
                verified!
                handle_warnings(sql)
                result
              end
            end
          end

          def exec_stmt_and_free(sql, name, binds, cache_stmt: false, async: false)
            sql = transform_query(sql)
            check_if_write_query(sql)

            mark_transaction_written_if_write(sql)

            type_casted_binds = type_casted_binds(binds)

            log(sql, name, binds, type_casted_binds, async: async) do
              with_raw_connection do |conn|
                sync_timezone_changes(conn)

                if cache_stmt
                  stmt = @statements[sql] ||= conn.prepare(sql)
                else
                  stmt = conn.prepare(sql)
                end

                begin
                  result = ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                    stmt.execute(*type_casted_binds)
                  end
                  verified!
                  result
                rescue ::Mysql2::Error => e
                  if cache_stmt
                    @statements.delete(sql)
                  else
                    stmt.close
                  end
                  raise e
                end

                ret = yield stmt, result
                result.free if result
                stmt.close unless cache_stmt
                ret
              end
            end
          end
      end
    end
  end
end
