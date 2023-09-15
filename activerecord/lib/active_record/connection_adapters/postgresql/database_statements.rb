# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module DatabaseStatements
        def explain(arel, binds = [], options = [])
          sql    = build_explain_clause(options) + " " + to_sql(arel, binds)
          result = internal_exec_query(sql, "EXPLAIN", binds)
          PostgreSQL::ExplainPrettyPrinter.new.pp(result)
        end

        # Queries the database and returns the results in an Array-like object
        def query(sql, name = nil) # :nodoc:
          mark_transaction_written_if_write(sql)

          log(sql, name) do
            with_raw_connection do |conn|
              conn.async_exec(sql).map_types!(@type_map_for_results).values
            end
          end
        end

        READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :close, :declare, :fetch, :move, :set, :show
        ) # :nodoc:
        private_constant :READ_QUERY

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        rescue ArgumentError # Invalid encoding
          !READ_QUERY.match?(sql.b)
        end

        # Executes an SQL statement, returning a PG::Result object on success
        # or raising a PG::Error exception otherwise.
        #
        # Setting +allow_retry+ to true causes the db to reconnect and retry
        # executing the SQL statement in case of a connection-related exception.
        # This option should only be enabled for known idempotent queries.
        #
        # Note: the PG::Result object is manually memory managed; if you don't
        # need it specifically, you may want consider the <tt>exec_query</tt> wrapper.
        def execute(...) # :nodoc:
          super
        ensure
          @notice_receiver_sql_warnings = []
        end

        def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
          log(sql, name, async: async) do
            with_raw_connection(allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |conn|
              result = conn.async_exec(sql)
              handle_warnings(result)
              result
            end
          end
        end

        def internal_exec_query(sql, name = "SQL", binds = [], prepare: false, async: false, allow_retry: false, materialize_transactions: true) # :nodoc:
          execute_and_clear(sql, name, binds, prepare: prepare, async: async, allow_retry: allow_retry, materialize_transactions: materialize_transactions) do |result|
            types = {}
            fields = result.fields
            fields.each_with_index do |fname, i|
              ftype = result.ftype i
              fmod  = result.fmod i
              types[fname] = types[i] = get_oid_type(ftype, fmod, fname)
            end
            build_result(columns: fields, rows: result.values, column_types: types)
          end
        end

        def exec_delete(sql, name = nil, binds = []) # :nodoc:
          execute_and_clear(sql, name, binds) { |result| result.cmd_tuples }
        end
        alias :exec_update :exec_delete

        def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil, returning: nil) # :nodoc:
          if use_insert_returning? || pk == false
            super
          else
            result = internal_exec_query(sql, name, binds)
            unless sequence_name
              table_ref = extract_table_ref_from_insert_sql(sql)
              if table_ref
                pk = primary_key(table_ref) if pk.nil?
                pk = suppress_composite_primary_key(pk)
                sequence_name = default_sequence_name(table_ref, pk)
              end
              return result unless sequence_name
            end
            last_insert_id_result(sequence_name)
          end
        end

        # Begins a transaction.
        def begin_db_transaction # :nodoc:
          internal_execute("BEGIN", "TRANSACTION", allow_retry: true, materialize_transactions: false)
        end

        def begin_isolated_db_transaction(isolation) # :nodoc:
          internal_execute("BEGIN ISOLATION LEVEL #{transaction_isolation_levels.fetch(isolation)}", "TRANSACTION", allow_retry: true, materialize_transactions: false)
        end

        # Commits a transaction.
        def commit_db_transaction # :nodoc:
          internal_execute("COMMIT", "TRANSACTION", allow_retry: false, materialize_transactions: true)
        end

        # Aborts a transaction.
        def exec_rollback_db_transaction # :nodoc:
          cancel_any_running_query
          internal_execute("ROLLBACK", "TRANSACTION", allow_retry: false, materialize_transactions: true)
        end

        def exec_restart_db_transaction # :nodoc:
          cancel_any_running_query
          internal_execute("ROLLBACK AND CHAIN", "TRANSACTION", allow_retry: false, materialize_transactions: true)
        end

        # From https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-CURRENT
        HIGH_PRECISION_CURRENT_TIMESTAMP = Arel.sql("CURRENT_TIMESTAMP").freeze # :nodoc:
        private_constant :HIGH_PRECISION_CURRENT_TIMESTAMP

        def high_precision_current_timestamp
          HIGH_PRECISION_CURRENT_TIMESTAMP
        end

        def build_explain_clause(options = [])
          return "EXPLAIN" if options.empty?

          "EXPLAIN (#{options.join(", ").upcase})"
        end

        private
          IDLE_TRANSACTION_STATUSES = [PG::PQTRANS_IDLE, PG::PQTRANS_INTRANS, PG::PQTRANS_INERROR]
          private_constant :IDLE_TRANSACTION_STATUSES

          def cancel_any_running_query
            return if @raw_connection.nil? || IDLE_TRANSACTION_STATUSES.include?(@raw_connection.transaction_status)

            @raw_connection.cancel
            @raw_connection.block
          rescue PG::Error
          end

          def execute_batch(statements, name = nil)
            execute(combine_multi_statements(statements))
          end

          def build_truncate_statements(table_names)
            ["TRUNCATE TABLE #{table_names.map(&method(:quote_table_name)).join(", ")}"]
          end

          # Returns the current ID of a table's sequence.
          def last_insert_id_result(sequence_name)
            internal_exec_query("SELECT currval(#{quote(sequence_name)})", "SQL")
          end

          def returning_column_values(result)
            result.rows.first
          end

          def suppress_composite_primary_key(pk)
            pk unless pk.is_a?(Array)
          end

          def handle_warnings(sql)
            @notice_receiver_sql_warnings.each do |warning|
              next if warning_ignored?(warning)

              warning.sql = sql
              ActiveRecord.db_warnings_action.call(warning)
            end
          end

          def warning_ignored?(warning)
            ["WARNING", "ERROR", "FATAL", "PANIC"].exclude?(warning.level) || super
          end
      end
    end
  end
end
