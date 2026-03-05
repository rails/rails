# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module DatabaseStatements
        def explain(arel, binds = [], options = [])
          sql    = build_explain_clause(options) + " " + to_sql(arel, binds)
          result = select_all(sql, "EXPLAIN", binds)
          PostgreSQL::ExplainPrettyPrinter.new.pp(result)
        end

        # Queries the database and returns the results in an Array-like object
        def query_rows(sql, name = "SCHEMA", allow_retry: true, materialize_transactions: false) # :nodoc:
          intent = internal_build_intent(sql, name, allow_retry:, materialize_transactions:)
          intent.execute!
          result = intent.raw_result
          result.map_types!(@type_map_for_results).values
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

        def _exec_insert(intent, pk = nil, sequence_name = nil, returning: nil) # :nodoc:
          if use_insert_returning? || pk == false
            super
          else
            intent.execute!
            result = intent.cast_result
            unless sequence_name
              table_ref = extract_table_ref_from_insert_sql(intent.raw_sql)
              if table_ref
                pk = schema_cache.primary_keys(table_ref) if pk.nil?
                pk = suppress_composite_primary_key(pk)
                sequence_name = default_sequence_name(table_ref, pk)
              end
              return result unless sequence_name
            end

            query_all("SELECT currval(#{quote(sequence_name)})", "SQL")
          end
        end

        # Begins a transaction.
        def begin_db_transaction # :nodoc:
          query_command("BEGIN", "TRANSACTION", allow_retry: true, materialize_transactions: false)
        end

        def begin_isolated_db_transaction(isolation) # :nodoc:
          query_command("BEGIN ISOLATION LEVEL #{transaction_isolation_levels.fetch(isolation)}", "TRANSACTION", allow_retry: true, materialize_transactions: false)
        end

        # Commits a transaction.
        def commit_db_transaction # :nodoc:
          query_command("COMMIT", "TRANSACTION", allow_retry: false, materialize_transactions: true)
        end

        # Aborts a transaction.
        def exec_rollback_db_transaction # :nodoc:
          cancel_any_running_query
          query_command("ROLLBACK", "TRANSACTION", allow_retry: false, materialize_transactions: true)
        end

        def exec_restart_db_transaction # :nodoc:
          cancel_any_running_query
          query_command("ROLLBACK AND CHAIN", "TRANSACTION", allow_retry: false, materialize_transactions: true)
        end

        # From https://www.postgresql.org/docs/current/functions-datetime.html#FUNCTIONS-DATETIME-CURRENT
        HIGH_PRECISION_CURRENT_TIMESTAMP = Arel.sql("CURRENT_TIMESTAMP", retryable: true).freeze # :nodoc:
        private_constant :HIGH_PRECISION_CURRENT_TIMESTAMP

        def high_precision_current_timestamp
          HIGH_PRECISION_CURRENT_TIMESTAMP
        end

        def build_explain_clause(options = [])
          return "EXPLAIN" if options.empty?

          options = options.flat_map do |option|
            option.is_a?(Hash) ? option.to_a.map { |nested| nested.join(" ") } : option
          end

          "EXPLAIN (#{options.join(", ").upcase})"
        end

        # Set when constraints will be checked for the current transaction.
        #
        # Not passing any specific constraint names will set the value for all deferrable constraints.
        #
        # [<tt>deferred</tt>]
        #   Valid values are +:deferred+ or +:immediate+.
        #
        # See https://www.postgresql.org/docs/current/sql-set-constraints.html
        def set_constraints(deferred, *constraints)
          unless %i[deferred immediate].include?(deferred)
            raise ArgumentError, "deferred must be :deferred or :immediate"
          end

          constraints = if constraints.empty?
            "ALL"
          else
            constraints.map { |c| quote_table_name(c) }.join(", ")
          end
          execute("SET CONSTRAINTS #{constraints} #{deferred.to_s.upcase}")
        end

        def execute_batch(statements, name = nil, **kwargs) # :nodoc:
          intent = QueryIntent.new(
            adapter: self,
            processed_sql: combine_multi_statements(statements),
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

        private
          IDLE_TRANSACTION_STATUSES = [PG::PQTRANS_IDLE, PG::PQTRANS_INTRANS, PG::PQTRANS_INERROR]
          private_constant :IDLE_TRANSACTION_STATUSES

          def cancel_any_running_query
            return if @raw_connection.nil? || IDLE_TRANSACTION_STATUSES.include?(@raw_connection.transaction_status)

            # Skip @raw_connection.cancel (PG::Connection#cancel) when using libpq >= 18 with pg < 1.6.0,
            # because the pg gem cannot obtain the backend_key in that case.
            # This method is only called from exec_rollback_db_transaction and exec_restart_db_transaction.
            # Even without cancel, rollback will still run. However, since any running
            # query must finish first, the rollback may take longer.
            if !(PG.library_version >= 18_00_00 && Gem::Version.new(PG::VERSION) < Gem::Version.new("1.6.0"))
              @raw_connection.cancel
            end
            @raw_connection.block
          rescue PG::Error
          end

          def perform_query(raw_connection, intent)
            result = if intent.prepare
              begin
                stmt_key = prepare_statement(intent.processed_sql, intent.binds, raw_connection)
                intent.notification_payload[:statement_name] = stmt_key
                raw_connection.exec_prepared(stmt_key, intent.type_casted_binds)
              rescue PG::FeatureNotSupported => error
                if is_cached_plan_failure?(error)
                  # Nothing we can do if we are in a transaction because all commands
                  # will raise InFailedSQLTransaction
                  if in_transaction?
                    raise PreparedStatementCacheExpired.new(error.message, connection_pool: @pool)
                  else
                    @lock.synchronize do
                      # outside of transactions we can simply flush this query and retry
                      @statements.delete sql_key(intent.processed_sql)
                    end
                    retry
                  end
                end

                raise
              end
            elsif intent.has_binds?
              raw_connection.exec_params(intent.processed_sql, intent.type_casted_binds)
            else
              raw_connection.async_exec(intent.processed_sql)
            end

            verified!

            intent.notification_payload[:affected_rows] = result.cmd_tuples
            intent.notification_payload[:row_count] = result.ntuples
            result
          end

          def cast_result(result)
            ar_result = if result.fields.empty?
              ActiveRecord::Result.empty(affected_rows: result.cmd_tuples)
            else
              fields = result.fields
              types = Array.new(fields.size)
              fields.size.times do |index|
                ftype = result.ftype(index)
                fmod  = result.fmod(index)
                types[index] = get_oid_type(ftype, fmod, fields[index])
              end

              ActiveRecord::Result.new(fields, result.values, types.freeze, affected_rows: result.cmd_tuples)
            end

            result.clear
            ar_result
          end

          def affected_rows(result)
            affected_rows = result.cmd_tuples
            result.clear
            affected_rows
          end

          def build_truncate_statements(table_names)
            ["TRUNCATE TABLE #{table_names.map(&method(:quote_table_name)).join(", ")}"]
          end

          def returning_column_values(result)
            result.rows.first
          end

          def suppress_composite_primary_key(pk)
            pk unless pk.is_a?(Array)
          end

          def handle_warnings(result, sql)
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
