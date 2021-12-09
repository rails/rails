# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module DatabaseStatements
        READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :pragma
        ) # :nodoc:
        private_constant :READ_QUERY

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        rescue ArgumentError # Invalid encoding
          !READ_QUERY.match?(sql.b)
        end

        def explain(arel, binds = [])
          sql = "EXPLAIN QUERY PLAN #{to_sql(arel, binds)}"
          SQLite3::ExplainPrettyPrinter.new.pp(exec_query(sql, "EXPLAIN", []))
        end

        def execute(sql, name = nil) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)

          materialize_transactions
          mark_transaction_written_if_write(sql)

          log(sql, name) do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.execute(sql)
            end
          end
        end

        def exec_query(sql, name = nil, binds = [], prepare: false, async: false) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)

          materialize_transactions
          mark_transaction_written_if_write(sql)

          type_casted_binds = type_casted_binds(binds)

          log(sql, name, binds, type_casted_binds, async: async) do
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

              build_result(columns: cols, rows: records)
            end
          end
        end

        def exec_delete(sql, name = "SQL", binds = []) # :nodoc:
          exec_query(sql, name, binds)
          @connection.changes
        end
        alias :exec_update :exec_delete

        def begin_isolated_db_transaction(isolation) # :nodoc:
          raise TransactionIsolationError, "SQLite3 only supports the `read_uncommitted` transaction isolation level" if isolation != :read_uncommitted
          raise StandardError, "You need to enable the shared-cache mode in SQLite mode before attempting to change the transaction isolation level" unless shared_cache?

          ActiveSupport::IsolatedExecutionState[:active_record_read_uncommitted] = @connection.get_first_value("PRAGMA read_uncommitted")
          @connection.read_uncommitted = true
          begin_db_transaction
        end

        def begin_db_transaction # :nodoc:
          log("begin transaction", "TRANSACTION") { @connection.transaction }
        end

        def commit_db_transaction # :nodoc:
          log("commit transaction", "TRANSACTION") { @connection.commit }
          reset_read_uncommitted
        end

        def exec_rollback_db_transaction # :nodoc:
          log("rollback transaction", "TRANSACTION") { @connection.rollback }
          reset_read_uncommitted
        end

        # https://stackoverflow.com/questions/17574784
        # https://www.sqlite.org/lang_datefunc.html
        HIGH_PRECISION_CURRENT_TIMESTAMP = Arel.sql("STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')").freeze # :nodoc:
        private_constant :HIGH_PRECISION_CURRENT_TIMESTAMP

        def high_precision_current_timestamp
          HIGH_PRECISION_CURRENT_TIMESTAMP
        end

        private
          def reset_read_uncommitted
            read_uncommitted = ActiveSupport::IsolatedExecutionState[:active_record_read_uncommitted]
            return unless read_uncommitted

            @connection.read_uncommitted = read_uncommitted
          end

          def execute_batch(statements, name = nil)
            statements = statements.map { |sql| transform_query(sql) }
            sql = combine_multi_statements(statements)

            check_if_write_query(sql)

            materialize_transactions
            mark_transaction_written_if_write(sql)

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

          def build_truncate_statement(table_name)
            "DELETE FROM #{quote_table_name(table_name)}"
          end
      end
    end
  end
end
