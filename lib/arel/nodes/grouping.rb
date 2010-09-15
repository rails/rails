module Arel
  module Nodes
    class Grouping < Arel::Nodes::Node
      attr_accessor :expr

      def initialize expression
        @expr = expression
      end

      # FIXME: this method should go away.  I don't like people calling
      # to_sql on non-head nodes.  This forces us to walk the AST until we
      # can find a node that has a "relation" member.
      #
      # Maybe we should just use `Table.engine`?  :'(
      def to_sql
        viz = Visitors::ToSql.new Table.engine
        viz.accept self
      end
    end
  end
end
