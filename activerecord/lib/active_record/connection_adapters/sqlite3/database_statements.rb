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

        def begin_deferred_transaction(isolation = nil) # :nodoc:
          internal_begin_transaction(:deferred, isolation)
        end

        def begin_isolated_db_transaction(isolation) # :nodoc:
          internal_begin_transaction(:deferred, isolation)
        end

        def begin_db_transaction # :nodoc:
          internal_begin_transaction(:immediate, nil)
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
        HIGH_PRECISION_CURRENT_TIMESTAMP = Arel.sql("STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')", retryable: true).freeze # :nodoc:
        private_constant :HIGH_PRECISION_CURRENT_TIMESTAMP

        def high_precision_current_timestamp
          HIGH_PRECISION_CURRENT_TIMESTAMP
        end

        def execute(...) # :nodoc:
          # SQLite3Adapter was refactored to use ActiveRecord::Result internally
          # but for backward compatibility we have to keep returning arrays of hashes here
          super&.to_a
        end

        private
          def internal_begin_transaction(mode, isolation)
            if isolation
              raise TransactionIsolationError, "SQLite3 only supports the `read_uncommitted` transaction isolation level" if isolation != :read_uncommitted
              raise StandardError, "You need to enable the shared-cache mode in SQLite mode before attempting to change the transaction isolation level" unless shared_cache?
            end

            log("begin #{mode} transaction", "TRANSACTION") do
              with_raw_connection(allow_retry: true, materialize_transactions: false) do |conn|
                if isolation
                  ActiveSupport::IsolatedExecutionState[:active_record_read_uncommitted] = conn.get_first_value("PRAGMA read_uncommitted")
                  conn.read_uncommitted = true
                end
                result = conn.transaction(mode)
                verified!
                result
              end
            end
          end

          def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:)
            if prepare
              stmt = @statements[sql] ||= raw_connection.prepare(sql)
              stmt.reset!
              stmt.bind_params(type_casted_binds)

              result = if stmt.column_count.zero? # No return
                stmt.step
                ActiveRecord::Result.empty
              else
                ActiveRecord::Result.new(stmt.columns, stmt.to_a)
              end
            else
              # Don't cache statements if they are not prepared.
              stmt = raw_connection.prepare(sql)
              begin
                unless without_prepared_statement?(binds)
                  stmt.bind_params(type_casted_binds)
                end
                result = if stmt.column_count.zero? # No return
                  stmt.step
                  ActiveRecord::Result.empty
                else
                  ActiveRecord::Result.new(stmt.columns, stmt.to_a)
                end
              ensure
                stmt.close
              end
            end
            @last_affected_rows = raw_connection.changes
            verified!

            notification_payload[:row_count] = result.length
            result
          end

          def cast_result(result)
            # Given that SQLite3 doesn't really a Result type, raw_execute already return an ActiveRecord::Result
            # and we have nothing to cast here.
            result
          end

          def affected_rows(result)
            @last_affected_rows
          end

          def reset_read_uncommitted
            read_uncommitted = ActiveSupport::IsolatedExecutionState[:active_record_read_uncommitted]
            return unless read_uncommitted

            @raw_connection&.read_uncommitted = read_uncommitted
          end

          def execute_batch(statements, name = nil)
            sql = combine_multi_statements(statements)

            log(sql, name) do |notification_payload|
              with_raw_connection do |conn|
                conn.execute_batch2(sql)
                verified!
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
