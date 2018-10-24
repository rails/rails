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

        if Array === o.right && !o.right.empty?
          o.right.delete_if do |bind|
            if Arel::Nodes::BindParam === bind && Relation::QueryAttribute === bind.value
              !bind.value.boundable?
            end
          end
        end

        super
      end

      def visit_Arel_Nodes_SqlLiteral(*)
        @preparable = false
        super
      end
    end
  end
end
