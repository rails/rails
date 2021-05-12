# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module DatabaseStatements
        def explain(arel, binds = [])
          sql = "EXPLAIN #{to_sql(arel, binds)}"
          PostgreSQL::ExplainPrettyPrinter.new.pp(exec_query(sql, "EXPLAIN", binds))
        end

        # Queries the database and returns the results in an Array-like object
        def query(sql, name = nil) #:nodoc:
          materialize_transactions
          mark_transaction_written_if_write(sql)

          log(sql, name) do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.async_exec(sql).map_types!(@type_map_for_results).values
            end
          end
        end

        READ_QUERY = ActiveRecord::ConnectionAdapters::AbstractAdapter.build_read_query_regexp(
          :close, :declare, :fetch, :move, :set, :show
        ) # :nodoc:
        private_constant :READ_QUERY

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        end

        # Executes an SQL statement, returning a PG::Result object on success
        # or raising a PG::Error exception otherwise.
        # Note: the PG::Result object is manually memory managed; if you don't
        # need it specifically, you may want consider the <tt>exec_query</tt> wrapper.
        def execute(sql, name = nil)
          check_if_write_query(sql)

          materialize_transactions
          mark_transaction_written_if_write(sql)

          log(sql, name) do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.async_exec(sql)
            end
          end
        end

        def exec_query(sql, name = "SQL", binds = [], prepare: false, async: false)
          execute_and_clear(sql, name, binds, prepare: prepare, async: async) do |result|
            types = {}
            fields = result.fields
            fields.each_with_index do |fname, i|
              ftype = result.ftype i
              fmod  = result.fmod i
              case type = get_oid_type(ftype, fmod, fname)
              when Type::Integer, Type::Float, OID::Decimal, Type::String, Type::DateTime, Type::Boolean
                # skip if a column has already been type casted by pg decoders
              else types[fname] = type
              end
            end
            build_result(columns: fields, rows: result.values, column_types: types)
          end
        end

        def exec_delete(sql, name = nil, binds = [])
          execute_and_clear(sql, name, binds) { |result| result.cmd_tuples }
        end
        alias :exec_update :exec_delete

        def sql_for_insert(sql, pk, binds) # :nodoc:
          if pk.nil?
            # Extract the table from the insert sql. Yuck.
            table_ref = extract_table_ref_from_insert_sql(sql)
            pk = primary_key(table_ref) if table_ref
          end

          if pk = suppress_composite_primary_key(pk)
            sql = "#{sql} RETURNING #{quote_column_name(pk)}"
          end

          super
        end
        private :sql_for_insert

        def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil)
          if use_insert_returning? || pk == false
            super
          else
            result = exec_query(sql, name, binds)
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
        def begin_db_transaction
          execute("BEGIN", "TRANSACTION")
        end

        def begin_isolated_db_transaction(isolation)
          begin_db_transaction
          execute "SET TRANSACTION ISOLATION LEVEL #{transaction_isolation_levels.fetch(isolation)}"
        end

        # Commits a transaction.
        def commit_db_transaction
          execute("COMMIT", "TRANSACTION")
        end

        # Aborts a transaction.
        def exec_rollback_db_transaction
          execute("ROLLBACK", "TRANSACTION")
        end

        private
          def execute_batch(statements, name = nil)
            execute(combine_multi_statements(statements))
          end

          def build_truncate_statements(table_names)
            ["TRUNCATE TABLE #{table_names.map(&method(:quote_table_name)).join(", ")}"]
          end

          # Returns the current ID of a table's sequence.
          def last_insert_id_result(sequence_name)
            exec_query("SELECT currval(#{quote(sequence_name)})", "SQL")
          end

          def suppress_composite_primary_key(pk)
            pk unless pk.is_a?(Array)
          end
      end
    end
  end
end
