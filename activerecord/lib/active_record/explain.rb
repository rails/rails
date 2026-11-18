# frozen_string_literal: true

require "active_record/explain_registry"

module ActiveRecord
  module Explain
    # Executes the block with the collect flag enabled. Queries are collected
    # asynchronously by the subscriber and returned.
    def collecting_queries_for_explain # :nodoc:
      ExplainRegistry.start
      yield
      ExplainRegistry.queries
    ensure
      ExplainRegistry.reset
    end

    # Makes the adapter execute EXPLAIN for the tuples of queries and bindings.
    # Returns a formatted string ready to be logged.
    def exec_explain(queries, options = []) # :nodoc:
      str = with_connection do |c|
        queries.map do |sql, binds|
          msg = +"#{build_explain_clause(c, options)} #{sql}"
          unless binds.empty?
            msg << " "
            msg << binds.map.with_index { |attr, i| render_bind(c, attr, i) }.inspect
          end
          msg << "\n"
          msg << c.explain(sql, binds, options)
        end.join("\n")
      end
      # Overriding inspect to be more human readable, especially in the console.
      def str.inspect
        self
      end

      str
    end

    private
      def render_bind(connection, attr, i)
        if ActiveModel::Attribute === attr
          value = if attr.type.binary? && attr.value
            "<#{attr.value_for_database.to_s.bytesize} bytes of binary data>"
          else
            connection.type_cast(attr.value_for_database)
          end
          [attr.name, value]
        else
          ["$#{i + 1}", connection.type_cast(attr)]
        end
      end

      def build_explain_clause(connection, options = [])
        if connection.respond_to?(:build_explain_clause, true)
          connection.build_explain_clause(options)
        else
          "EXPLAIN for:"
        end
      end
  end
end
