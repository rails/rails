module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module DatabaseStatements
        def explain(arel, binds = [])
          sql     = "EXPLAIN #{to_sql(arel, binds)}"
          start   = Time.now
          result  = exec_query(sql, "EXPLAIN", binds)
          elapsed = Time.now - start

          MySQL::ExplainPrettyPrinter.new.pp(result, elapsed)
        end

        # Returns an ActiveRecord::Result instance.
        def select_all(arel, name = nil, binds = [], preparable: nil)
          result = if ExplainRegistry.collect? && prepared_statements
            unprepared_statement { super }
          else
            super
          end
          @connection.next_result while @connection.more_results?
          result
        end

        # Returns an array of arrays containing the field values.
        # Order is the same as that returned by +columns+.
        def select_rows(sql, name = nil, binds = [])
          select_result(sql, name, binds) do |result|
            @connection.next_result while @connection.more_results?
            result.to_a
          end
        end

        # Executes the SQL statement in the context of this connection.
        def execute(sql, name = nil)
          # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
          # made since we established the connection
          @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone

          log(sql, name) do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.query(sql)
            end
          end
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

        def begin_db_transaction
          execute "BEGIN"
        end

        def begin_isolated_db_transaction(isolation)
          execute "SET TRANSACTION ISOLATION LEVEL #{transaction_isolation_levels.fetch(isolation)}"
          begin_db_transaction
        end

        def commit_db_transaction # :nodoc:
          execute "COMMIT"
        end

        def exec_rollback_db_transaction # :nodoc:
          execute "ROLLBACK"
        end

        # In the simple case, MySQL allows us to place JOINs directly into the UPDATE
        # query. However, this does not allow for LIMIT, OFFSET and ORDER. To support
        # these, we must use a subquery.
        def join_to_update(update, select, key) # :nodoc:
          if select.limit || select.offset || select.orders.any?
            super
          else
            update.table select.source
            update.wheres = select.constraints
          end
        end

        def empty_insert_statement_value
          "VALUES ()"
        end

        protected

          # MySQL is too stupid to create a temporary table for use subquery, so we have
          # to give it some prompting in the form of a subsubquery. Ugh!
          def subquery_for(key, select)
            subsubselect = select.clone
            subsubselect.projections = [key]

            # Materialize subquery by adding distinct
            # to work with MySQL 5.7.6 which sets optimizer_switch='derived_merge=on'
            subsubselect.distinct unless select.limit || select.offset || select.orders.any?

            subselect = Arel::SelectManager.new(select.engine)
            subselect.project Arel.sql(key.name)
            subselect.from subsubselect.as("__active_record_temp")
          end

          def last_inserted_id(result)
            @connection.last_id
          end

        private

          def select_result(sql, name = nil, binds = [])
            if without_prepared_statement?(binds)
              execute_and_free(sql, name) { |result| yield result }
            else
              exec_stmt_and_free(sql, name, binds, cache_stmt: true) { |_, result| yield result }
            end
          end

          def execute_and_free(sql, name = nil)
            yield execute(sql, name)
          end

          def exec_stmt_and_free(sql, name, binds, cache_stmt: false)
            # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
            # made since we established the connection
            @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone

            type_casted_binds = type_casted_binds(binds)

            log(sql, name, binds, type_casted_binds) do
              if cache_stmt
                cache = @statements[sql] ||= {
                  stmt: @connection.prepare(sql)
                }
                stmt = cache[:stmt]
              else
                stmt = @connection.prepare(sql)
              end

              begin
                result =
                  ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
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
