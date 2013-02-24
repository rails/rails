require 'active_support/lazy_load_hooks'

module ActiveRecord
  module Explain
    # Relation#explain needs to be able to collect the queries.
    def collecting_queries_for_explain # :nodoc:
      current = Thread.current
      original, current[:available_queries_for_explain] = current[:available_queries_for_explain], []
      return yield, current[:available_queries_for_explain]
    ensure
      # Note that the return value above does not depend on this assigment.
      current[:available_queries_for_explain] = original
    end

    # Makes the adapter execute EXPLAIN for the tuples of queries and bindings.
    # Returns a formatted string ready to be logged.
    def exec_explain(queries) # :nodoc:
      str = queries && queries.map do |sql, bind|
        [].tap do |msg|
          msg << "EXPLAIN for: #{sql}"
          unless bind.empty?
            bind_msg = bind.map {|col, val| [col.name, val]}.inspect
            msg.last << " #{bind_msg}"
          end
          msg << connection.explain(sql, bind)
        end.join("\n")
      end.join("\n")

      # Overriding inspect to be more human readable, specially in the console.
      def str.inspect
        self
      end
      str
    end
  end
end
