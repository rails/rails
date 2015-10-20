module ActiveRecord
  module ConnectionAdapters
    module DetermineIfPreparableVisitor
      attr_reader :preparable

      def accept(*)
        @preparable = true
        super
      end

      def visit_Arel_Nodes_In(*)
        @preparable = false
        super
      end

      def visit_Arel_Nodes_SqlLiteral(*)
        @preparable = false
        super
      end
    end
  end
end
