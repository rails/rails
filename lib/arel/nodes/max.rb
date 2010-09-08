module Arel
  module Nodes
    class Max
      attr_accessor :expressions, :alias

      def initialize expr, aliaz = nil
        @expressions = expr
        @alias       = aliaz
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
