module Arel
  module Nodes
    class Count
      attr_accessor :expressions, :distinct, :alias

      def initialize expr, distinct = false
        @expressions = expr
        @distinct    = distinct
        @alias       = nil
      end

      def as aliaz
        self.alias = SqlLiteral.new(aliaz)
        self
      end

      def to_sql
        viz = Visitors::ToSql.new Table.engine
        viz.accept self
      end
    end
  end
end
