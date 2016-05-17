module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      class ExplainPrettyPrinter # :nodoc:
        # Pretty prints the result of an EXPLAIN QUERY PLAN in a way that resembles
        # the output of the SQLite shell:
        #
        #   0|0|0|SEARCH TABLE users USING INTEGER PRIMARY KEY (rowid=?) (~1 rows)
        #   0|1|1|SCAN TABLE posts (~100000 rows)
        #
        def pp(result)
          result.rows.map do |row|
            row.join('|')
          end.join("\n") + "\n"
        end
      end
    end
  end
end
