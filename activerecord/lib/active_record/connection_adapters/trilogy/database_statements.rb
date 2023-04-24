# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Trilogy
      module DatabaseStatements
        READ_QUERY = AbstractAdapter.build_read_query_regexp(
          :desc, :describe, :set, :show, :use
        ) # :nodoc:
        private_constant :READ_QUERY

        HIGH_PRECISION_CURRENT_TIMESTAMP = Arel.sql("CURRENT_TIMESTAMP(6)").freeze # :nodoc:
        private_constant :HIGH_PRECISION_CURRENT_TIMESTAMP

        def select_all(*, **) # :nodoc:
          result = nil
          with_raw_connection do |conn|
            result = super
            conn.next_result while conn.more_results_exist?
          end
          result
        end

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        rescue ArgumentError # Invalid encoding
          !READ_QUERY.match?(sql.b)
        end

        def explain(arel, binds = [], options = [])
          sql     = build_explain_clause(options) + " " + to_sql(arel, binds)
          start   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result  = exec_query(sql, "EXPLAIN", binds)
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

          MySQL::ExplainPrettyPrinter.new.pp(result, elapsed)
        end

        def exec_query(sql, name = "SQL", binds = [], prepare: false, async: false) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)

          result = raw_execute(sql, name, async: async)
          ActiveRecord::Result.new(result.fields, result.to_a)
        end

        def exec_insert(sql, name, binds, pk = nil, sequence_name = nil) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)

          raw_execute(to_sql(sql, binds), name)
        end

        def exec_delete(sql, name = nil, binds = []) # :nodoc:
          sql = transform_query(sql)
          check_if_write_query(sql)

          result = raw_execute(to_sql(sql, binds), name)
          result.affected_rows
        end

        alias :exec_update :exec_delete # :nodoc:

        def high_precision_current_timestamp
          HIGH_PRECISION_CURRENT_TIMESTAMP
        end

        def build_explain_clause(options = [])
          return "EXPLAIN" if options.empty?

          explain_clause = "EXPLAIN #{options.join(" ").upcase}"

          if analyze_without_explain? && explain_clause.include?("ANALYZE")
            explain_clause.sub("EXPLAIN ", "")
          else
            explain_clause
          end
        end

        private
          def last_inserted_id(result)
            result.last_insert_id
          end
      end
    end
  end
end
