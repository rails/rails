# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Mysql2
      module DatabaseStatements
        # Returns an ActiveRecord::Result instance.
        def select_all(*, **) # :nodoc:
          if ExplainRegistry.collect? && prepared_statements
            unprepared_statement { super }
          else
            super
          end
        end

        private
          def sync_timezone_changes(raw_connection)
            raw_connection.query_options[:database_timezone] = default_timezone
          end

          def execute_batch(statements, name = nil)
            combine_multi_statements(statements).each do |statement|
              with_raw_connection do |conn|
                raw_execute(statement, name)
              end
            end
          end

          def last_inserted_id(result)
            if supports_insert_returning?
              super
            else
              @raw_connection&.last_id
            end
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

          def raw_execute(sql, name, binds = nil, prepare: false, async: false, allow_retry: false, materialize_transactions: true)
            log(sql, name, async: async) do |notification_payload|
              with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
                sync_timezone_changes(conn)

                result = if prepare
                  stmt = @statements[sql] ||= conn.prepare(sql)

                  begin
                    ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                      stmt.execute(*type_casted_binds)
                    end
                  rescue ::Mysql2::Error
                    @statements.delete(sql)
                    stmt.close
                    raise
                  end
                  verified!
                else
                  conn.query(sql)
                end

                @affected_rows_before_warnings = conn.affected_rows
                conn.abandon_results!

                verified!
                handle_warnings(sql)
                notification_payload[:row_count] = result&.size || 0
                result
              end
            end
          end

          def cast_result(result)
            if result.nil? || result.size.zero?
              ActiveRecord::Result.empty
            else
              ActiveRecord::Result.new(result.fields, result.to_a)
            end
          end

          def affected_rows(result)
            @affected_rows_before_warnings
          end
      end
    end
  end
end
