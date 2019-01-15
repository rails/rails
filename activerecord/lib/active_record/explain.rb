# frozen_string_literal: true

require "active_record/explain_registry"

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
      str = queries.map do |sql, binds|
        msg = +"EXPLAIN for: #{sql}"
        unless binds.empty?
          msg << " "
          msg << binds.map { |attr| render_bind(attr) }.inspect
        end
        msg << "\n"
        msg << connection.explain(sql, binds)
      end.join("\n")

      # Overriding inspect to be more human readable, especially in the console.
      def str.inspect
        self
      end

      str
    end

    private

      def render_bind(attr)
        value = if attr.type.binary? && attr.value
          "<#{attr.value_for_database.to_s.bytesize} bytes of binary data>"
        else
          connection.type_cast(attr.value_for_database)
        end

        [attr.name, value]
      end
  end
end
