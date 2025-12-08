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
          result = query_rows(sql, "EXPLAIN")
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
          query_command("COMMIT TRANSACTION", "TRANSACTION", allow_retry: true, materialize_transactions: false)
        end

        def exec_rollback_db_transaction # :nodoc:
          query_command("ROLLBACK TRANSACTION", "TRANSACTION", allow_retry: true, materialize_transactions: false)
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

        def reset_isolation_level # :nodoc:
          query_command("PRAGMA read_uncommitted=#{@previous_read_uncommitted}", "TRANSACTION", allow_retry: true, materialize_transactions: false)
          @previous_read_uncommitted = nil
        end

        def default_insert_value(column) # :nodoc:
          if column.default_function
            Arel.sql(column.default_function)
          else
            column.default
          end
        end

        private
          def internal_begin_transaction(mode, isolation)
            if isolation
              raise TransactionIsolationError, "SQLite3 only supports the `read_uncommitted` transaction isolation level" if isolation != :read_uncommitted
              raise StandardError, "You need to enable the shared-cache mode in SQLite mode before attempting to change the transaction isolation level" unless shared_cache?
            end

            query_command("BEGIN #{mode} TRANSACTION", "TRANSACTION", allow_retry: true, materialize_transactions: false)
            if isolation
              @previous_read_uncommitted = query_value("PRAGMA read_uncommitted", "TRANSACTION")
              query_command("PRAGMA read_uncommitted=ON", "TRANSACTION", allow_retry: true, materialize_transactions: false)
            end
          end

          def perform_query(raw_connection, intent)
            total_changes_before_query = raw_connection.total_changes
            affected_rows = nil

            if intent.batch
              raw_connection.execute_batch2(intent.processed_sql)
            else
              stmt = if intent.prepare
                @statements[intent.processed_sql] ||= raw_connection.prepare(intent.processed_sql)
                @statements[intent.processed_sql].reset!
              else
                # Don't cache statements if they are not prepared.
                raw_connection.prepare(intent.processed_sql)
              end
              begin
                if intent.has_binds?
                  stmt.bind_params(intent.type_casted_binds)
                end
                result = if stmt.column_count.zero? # No return
                  stmt.step

                  affected_rows = if raw_connection.total_changes > total_changes_before_query
                    raw_connection.changes
                  else
                    0
                  end

                  ActiveRecord::Result.empty(affected_rows: affected_rows)
                else
                  rows = stmt.to_a

                  affected_rows = if raw_connection.total_changes > total_changes_before_query
                    raw_connection.changes
                  else
                    0
                  end

                  ActiveRecord::Result.new(stmt.columns, rows, stmt.types.map { |t| type_map.lookup(t) }, affected_rows: affected_rows)
                end
              ensure
                stmt.close unless intent.prepare
              end
            end
            verified!

            intent.notification_payload[:affected_rows] = affected_rows
            intent.notification_payload[:row_count] = result&.length || 0
            result
          end

          def cast_result(result)
            # Given that SQLite3 doesn't have a Result type, raw_execute already returns an ActiveRecord::Result
            # so we have nothing to cast here.
            result
          end

          def affected_rows(result)
            result&.affected_rows
          end

          def execute_batch(statements, name = nil, **kwargs)
            sql = combine_multi_statements(statements)
            intent = QueryIntent.new(
              adapter: self,
              processed_sql: sql,
              name: name,
              batch: true,
              binds: kwargs[:binds] || [],
              prepare: kwargs[:prepare] || false,
              allow_async: kwargs[:async] || false,
              allow_retry: kwargs[:allow_retry] || false,
              materialize_transactions: kwargs[:materialize_transactions] != false
            )
            intent.execute!
            intent.finish
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
