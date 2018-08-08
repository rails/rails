# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module DatabaseStatements
        # Returns an ActiveRecord::Result instance.
        def select_all(*) # :nodoc:
          result = if ExplainRegistry.collect? && prepared_statements
            unprepared_statement { super }
          else
            super
          end
          discard_remaining_results
          result
        end

        def query(sql, name = nil) # :nodoc:
          execute(sql, name).to_a
        end

        # Executes the SQL statement in the context of this connection.
        def execute(sql, name = nil)
          # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
          # made since we established the connection
          @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone

          super
        end

        def exec_query(sql, name = "SQL", binds = [], prepare: false)
          if without_prepared_statement?(binds)
            execute_and_free(sql, name) do |result|
              ActiveRecord::Result.new(result.fields, result.to_a) if result
            end
          else
            exec_stmt_and_free(sql, name, binds, cache_stmt: prepare) do |_, result|
              ActiveRecord::Result.new(result.fields, result.to_a) if result
            end
          end
        end

        def exec_delete(sql, name = nil, binds = [])
          if without_prepared_statement?(binds)
            execute_and_free(sql, name) { @connection.affected_rows }
          else
            exec_stmt_and_free(sql, name, binds) { |stmt| stmt.affected_rows }
          end
        end
        alias :exec_update :exec_delete

        private
          def default_insert_value(column)
            Arel.sql("DEFAULT") unless column.auto_increment?
          end

          def last_inserted_id(result)
            @connection.last_id
          end

          def discard_remaining_results
            @connection.abandon_results!
          end

          def supports_set_server_option?
            @connection.respond_to?(:set_server_option)
          end

          def multi_statements_enabled?(flags)
            if flags.is_a?(Array)
              flags.include?("MULTI_STATEMENTS")
            else
              (flags & Mysql2::Client::MULTI_STATEMENTS) != 0
            end
          end

          def with_multi_statements
            previous_flags = @config[:flags]

            unless multi_statements_enabled?(previous_flags)
              if supports_set_server_option?
                @connection.set_server_option(Mysql2::Client::OPTION_MULTI_STATEMENTS_ON)
              else
                @config[:flags] = Mysql2::Client::MULTI_STATEMENTS
                reconnect!
              end
            end

            yield
          ensure
            unless multi_statements_enabled?(previous_flags)
              if supports_set_server_option?
                @connection.set_server_option(Mysql2::Client::OPTION_MULTI_STATEMENTS_OFF)
              else
                @config[:flags] = previous_flags
                reconnect!
              end
            end
          end

          def exec_stmt_and_free(sql, name, binds, cache_stmt: false)
            # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
            # made since we established the connection
            @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone

            type_casted_binds = type_casted_binds(binds)

            log(sql, name, binds, type_casted_binds) do
              if cache_stmt
                stmt = @statements[sql] ||= @connection.prepare(sql)
              else
                stmt = @connection.prepare(sql)
              end

              begin
                result = ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                  stmt.execute(*type_casted_binds)
                end
              rescue Mysql2::Error => e
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
