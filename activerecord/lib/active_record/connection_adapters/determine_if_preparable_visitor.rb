# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module DetermineIfPreparableVisitor
      attr_reader :preparable

      def accept(*)
        @preparable = true
        super
      end

      def visit_Arel_Nodes_In(o, collector)
        @preparable = false
        super
      end

      def visit_Arel_Nodes_NotIn(o, collector)
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
