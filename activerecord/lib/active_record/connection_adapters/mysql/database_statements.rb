# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module DatabaseStatements
        # Returns an ActiveRecord::Result instance.
        def select_all(*, **) # :nodoc:
          result = if ExplainRegistry.collect? && prepared_statements
            unprepared_statement { super }
          else
            super
          end
          @connection.abandon_results!
          result
        end

        def query(sql, name = nil) # :nodoc:
          execute(sql, name).to_a
        end

        READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :begin, :commit, :explain, :select, :set, :show, :release, :savepoint, :rollback, :describe, :desc, :with
        ) # :nodoc:
        private_constant :READ_QUERY

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        end

        # Executes the SQL statement in the context of this connection.
        def execute(sql, name = nil)
          if preventing_writes? && write_query?(sql)
            raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
          end

          # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
          # made since we established the connection
          @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone

          super
        end

        def exec_query(sql, name = "SQL", binds = [], prepare: false)
          if without_prepared_statement?(binds)
            execute_and_free(sql, name) do |result|
              if result
                ActiveRecord::Result.new(result.fields, result.to_a)
              else
                ActiveRecord::Result.new([], [])
              end
            end
          else
            exec_stmt_and_free(sql, name, binds, cache_stmt: prepare) do |_, result|
              if result
                ActiveRecord::Result.new(result.fields, result.to_a)
              else
                ActiveRecord::Result.new([], [])
              end
            end
          end
        end

        def exec_delete(sql, name = nil, binds = [])
          if without_prepared_statement?(binds)
            @lock.synchronize do
              execute_and_free(sql, name) { @connection.affected_rows }
            end
          else
            exec_stmt_and_free(sql, name, binds) { |stmt| stmt.affected_rows }
          end
        end
        alias :exec_update :exec_delete

        private
          def execute_batch(statements, name = nil)
            combine_multi_statements(statements).each do |statement|
              execute(statement, name)
            end
            @connection.abandon_results!
          end

          def default_insert_value(column)
            super unless column.auto_increment?
          end

          def last_inserted_id(result)
            @connection.last_id
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

          def combine_multi_statements(total_sql)
            total_sql.each_with_object([]) do |sql, total_sql_chunks|
              previous_packet = total_sql_chunks.last
              if max_allowed_packet_reached?(sql, previous_packet)
                total_sql_chunks << +sql
              else
                previous_packet << ";\n"
                previous_packet << sql
              end
            end
          end

          def max_allowed_packet_reached?(current_packet, previous_packet)
            if current_packet.bytesize > max_allowed_packet
              raise ActiveRecordError,
                "Fixtures set is too large #{current_packet.bytesize}. Consider increasing the max_allowed_packet variable."
            elsif previous_packet.nil?
              true
            else
              (current_packet.bytesize + previous_packet.bytesize + 2) > max_allowed_packet
            end
          end

          def max_allowed_packet
            @max_allowed_packet ||= show_variable("max_allowed_packet")
          end

          def exec_stmt_and_free(sql, name, binds, cache_stmt: false)
            if preventing_writes? && write_query?(sql)
              raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
            end

            materialize_transactions

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
