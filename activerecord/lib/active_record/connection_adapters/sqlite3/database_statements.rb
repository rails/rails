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

        def explain(arel, binds = [], _options = [])
          sql    = "EXPLAIN QUERY PLAN " + to_sql(arel, binds)
          result = internal_exec_query(sql, "EXPLAIN", [])
          SQLite3::ExplainPrettyPrinter.new.pp(result)
        end

        def internal_exec_query(sql, name = nil, binds = [], prepare: false, async: false) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)

          mark_transaction_written_if_write(sql)

          type_casted_binds = type_casted_binds(binds)

          log(sql, name, binds, type_casted_binds, async: async) do
            with_raw_connection do |conn|
              # Don't cache statements if they are not prepared
              unless prepare
                stmt = conn.prepare(sql)
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
                stmt = @statements[sql] ||= conn.prepare(sql)
                cols = stmt.columns
                stmt.reset!
                stmt.bind_params(type_casted_binds)
                records = stmt.to_a
              end
              verified!

              build_result(columns: cols, rows: records)
            end
          end
        end

        def exec_delete(sql, name = "SQL", binds = []) # :nodoc:
          internal_exec_query(sql, name, binds)
          @raw_connection.changes
        end
        alias :exec_update :exec_delete

        def begin_isolated_db_transaction(isolation) # :nodoc:
          raise TransactionIsolationError, "SQLite3 only supports the `read_uncommitted` transaction isolation level" if isolation != :read_uncommitted
          raise StandardError, "You need to enable the shared-cache mode in SQLite mode before attempting to change the transaction isolation level" unless shared_cache?

          with_raw_connection(allow_retry: true, materialize_transactions: false) do |conn|
            ActiveSupport::IsolatedExecutionState[:active_record_read_uncommitted] = conn.get_first_value("PRAGMA read_uncommitted")
            conn.read_uncommitted = true
            begin_db_transaction
          end
        end

        def begin_db_transaction # :nodoc:
          log("begin transaction", "TRANSACTION") do
            with_raw_connection(allow_retry: true, materialize_transactions: false) do |conn|
              result = conn.transaction
              verified!
              result
            end
          end
        end

        def commit_db_transaction # :nodoc:
          log("commit transaction", "TRANSACTION") do
            with_raw_connection(allow_retry: true, materialize_transactions: false) do |conn|
              conn.commit
            end
          end
          reset_read_uncommitted
        end

        def exec_rollback_db_transaction # :nodoc:
          log("rollback transaction", "TRANSACTION") do
            with_raw_connection(allow_retry: true, materialize_transactions: false) do |conn|
              conn.rollback
            end
          end
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
          def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: false)
            log(sql, name, async: async) do
              with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
                result = conn.execute(sql)
                verified!
                result
              end
            end
          end

          def reset_read_uncommitted
            read_uncommitted = ActiveSupport::IsolatedExecutionState[:active_record_read_uncommitted]
            return unless read_uncommitted

            @raw_connection&.read_uncommitted = read_uncommitted
          end

          def execute_batch(statements, name = nil)
            statements = statements.map { |sql| transform_query(sql) }
            sql = combine_multi_statements(statements)

            check_if_write_query(sql)
            mark_transaction_written_if_write(sql)

            log(sql, name) do
              with_raw_connection do |conn|
                result = conn.execute_batch2(sql)
                verified!
                result
              end
            end
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

          def returning_column_values(result)
            result.rows.first
          end
      end
    end
  end
end
