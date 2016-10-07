# frozen_string_literal: true
module Arel
  module Visitors
    module BindVisitor
      def initialize target
        @block = nil
        super
      end

      def accept node, collector, &block
        @block = block if block_given?
        super
      end

      private

      def visit_Arel_Nodes_Assignment o, collector
        if o.right.is_a? Arel::Nodes::BindParam
          collector = visit o.left, collector
          collector << " = "
          visit o.right, collector
        else
          super
        end
      end

      def visit_Arel_Nodes_BindParam o, collector
        if @block
          val = @block.call
          if String === val
            collector << val
          end
        else
          super
        end
      end

    end
  end
end
