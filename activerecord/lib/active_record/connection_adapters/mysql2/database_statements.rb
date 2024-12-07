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

            result = nil
            if binds.nil? || binds.empty?
              ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                result = raw_connection.query(sql)
                # Ref: https://github.com/brianmario/mysql2/pull/1383
                # As of mysql2 0.5.6 `#affected_rows` might raise Mysql2::Error if a prepared statement
                # from that same connection was GCed while `#query` released the GVL.
                # By avoiding to call `#affected_rows` when we have a result, we reduce the likeliness
                # of hitting the bug.
                @affected_rows_before_warnings = result&.size || raw_connection.affected_rows
              end
            elsif prepare
              stmt = @statements[sql] ||= raw_connection.prepare(sql)
              begin
                ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                  result = stmt.execute(*type_casted_binds)
                  @affected_rows_before_warnings = stmt.affected_rows
                end
              rescue ::Mysql2::Error
                @statements.delete(sql)
                raise
              end
            else
              stmt = raw_connection.prepare(sql)

              begin
                ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                  result = stmt.execute(*type_casted_binds)
                  @affected_rows_before_warnings = stmt.affected_rows
                end

                # Ref: https://github.com/brianmario/mysql2/pull/1383
                # by eagerly closing uncached prepared statements, we also reduce the chances of
                # that bug happening. It can still happen if `#execute` is used as we have no callback
                # to eagerly close the statement.
                if result
                  result.instance_variable_set(:@_ar_stmt_to_close, stmt)
                else
                  stmt.close
                end
              rescue ::Mysql2::Error
                stmt.close
                raise
              end
            end

            notification_payload[:affected_rows] = @affected_rows_before_warnings
            notification_payload[:row_count] = result&.size || 0

            raw_connection.abandon_results!

            verified!
            handle_warnings(sql)
            result
          ensure
            if reset_multi_statement && active?
              raw_connection.set_server_option(::Mysql2::Client::OPTION_MULTI_STATEMENTS_OFF)
            end
          end

          def cast_result(raw_result)
            return ActiveRecord::Result.empty if raw_result.nil?

            fields = raw_result.fields

            result = if fields.empty?
              ActiveRecord::Result.empty
            else
              ActiveRecord::Result.new(fields, raw_result.to_a)
            end

            free_raw_result(raw_result)

            result
          end

          def affected_rows(raw_result)
            free_raw_result(raw_result) if raw_result

            @affected_rows_before_warnings
          end

          def free_raw_result(raw_result)
            raw_result.free
            if stmt = raw_result.instance_variable_get(:@_ar_stmt_to_close)
              stmt.close
            end
          end
      end
    end
  end
end
