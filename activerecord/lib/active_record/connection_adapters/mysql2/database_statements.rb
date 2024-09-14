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
          def execute_batch(statements, name = nil, **kwargs)
            combine_multi_statements(statements).each do |statement|
              raw_execute(statement, name, batch: true, **kwargs)
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

          def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch: false)
            reset_multi_statement = if batch && !multi_statements_enabled?
              raw_connection.set_server_option(::Mysql2::Client::OPTION_MULTI_STATEMENTS_ON)
              true
            end

            # Make sure we carry over any changes to ActiveRecord.default_timezone that have been
            # made since we established the connection
            raw_connection.query_options[:database_timezone] = default_timezone

            result = if prepare
              stmt = @statements[sql] ||= raw_connection.prepare(sql)

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
              raw_connection.query(sql)
            end

            notification_payload[:row_count] = result&.size || 0

            @affected_rows_before_warnings = raw_connection.affected_rows
            raw_connection.abandon_results!

            verified!
            handle_warnings(sql)
            result
          ensure
            if reset_multi_statement && active?
              raw_connection.set_server_option(::Mysql2::Client::OPTION_MULTI_STATEMENTS_OFF)
            end
          end

          def cast_result(result)
            if result.nil? || result.fields.empty?
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
