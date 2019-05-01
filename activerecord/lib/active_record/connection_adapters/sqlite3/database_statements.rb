# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module DatabaseStatements
        READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(:begin, :commit, :explain, :select, :pragma, :release, :savepoint, :rollback) # :nodoc:
        private_constant :READ_QUERY

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        end

        def execute(sql, name = nil) #:nodoc:
          if preventing_writes? && write_query?(sql)
            raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
          end

          materialize_transactions

          log(sql, name) do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.execute(sql)
            end
          end
        end

        def exec_query(sql, name = nil, binds = [], prepare: false)
          if preventing_writes? && write_query?(sql)
            raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
          end

          materialize_transactions

          type_casted_binds = type_casted_binds(binds)

          log(sql, name, binds, type_casted_binds) do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              # Don't cache statements if they are not prepared
              unless prepare
                stmt = @connection.prepare(sql)
                begin
                  cols = stmt.columns
                  unless without_prepared_statement?(binds)
                    stmt.bind_params(type_casted_binds)
                  end
                  records = stmt.to_a
                ensure
                  stmt.close
                end
              else
                stmt = @statements[sql] ||= @connection.prepare(sql)
                cols = stmt.columns
                stmt.reset!
                stmt.bind_params(type_casted_binds)
                records = stmt.to_a
              end

              ActiveRecord::Result.new(cols, records)
            end
          end
        end

        def exec_delete(sql, name = "SQL", binds = [])
          exec_query(sql, name, binds)
          @connection.changes
        end
        alias :exec_update :exec_delete

        def begin_db_transaction #:nodoc:
          log("begin transaction", nil) { @connection.transaction }
        end

        def commit_db_transaction #:nodoc:
          log("commit transaction", nil) { @connection.commit }
        end

        def exec_rollback_db_transaction #:nodoc:
          log("rollback transaction", nil) { @connection.rollback }
        end


        private
          def execute_batch(sql, name = nil)
            if preventing_writes? && write_query?(sql)
              raise ActiveRecord::ReadOnlyError, "Write query attempted while in readonly mode: #{sql}"
            end

            materialize_transactions

            log(sql, name) do
              ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
                @connection.execute_batch2(sql)
              end
            end
          end

          def last_inserted_id(result)
            @connection.last_insert_row_id
          end

          def build_fixture_statements(fixture_set)
            fixture_set.flat_map do |table_name, fixtures|
              next if fixtures.empty?
              fixtures.map { |fixture| build_fixture_sql([fixture], table_name) }
            end.compact
          end

          def build_truncate_statements(*table_names)
            truncate_tables = table_names.map do |table_name|
              "DELETE FROM #{quote_table_name(table_name)}"
            end
            combine_multi_statements(truncate_tables)
          end
      end
    end
  end
end
