# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class WhereSql < Arel::Visitors::ToSql
      def initialize(inner_visitor, *args, &block)
        @inner_visitor = inner_visitor
        super(*args, &block)
      end

      private

        def visit_Arel_Nodes_SelectCore(o, collector)
          collector << "WHERE "
          wheres = o.wheres.map do |where|
            Nodes::SqlLiteral.new(@inner_visitor.accept(where, collector.class.new).value)
          end

          inject_join wheres, collector, " AND "
        end
    end
  end
end
