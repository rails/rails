module Arel
  module Nodes
    class Equality
      attr_accessor :left, :right

      def initialize left, right
        @left  = left
        @right = right
      end

      def to_sql
        viz = Visitors::ToSql.new left.relation.engine
        viz.accept self
      end
    end
  end
end
