require 'active_support/lazy_load_hooks'
require 'active_record/explain_registry'

module ActiveRecord
  module Explain
    # Executes the block with the collect flag enabled. Queries are collected
    # asynchronously by the subscriber and returned.
    def collecting_queries_for_explain # :nodoc:
      ExplainRegistry.collect = true
      yield
      ExplainRegistry.queries
    ensure
      ExplainRegistry.reset
    end

    # Makes the adapter execute EXPLAIN for the tuples of queries and bindings.
    # Returns a formatted string ready to be logged.
    def exec_explain(queries) # :nodoc:
      str = queries.map do |sql, bind|
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
