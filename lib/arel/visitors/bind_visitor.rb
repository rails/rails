module Arel
  module Visitors
    module BindVisitor
      def initialize target
        @block = nil
        super
      end

      def accept node, &block
        @block = block if block_given?
        super
      end

      private

      def visit_Arel_Nodes_Assignment o, a
        if o.right.is_a? Arel::Nodes::BindParam
          "#{visit o.left, a} = #{visit o.right, a}"
        else
          super
        end
      end

      def visit_Arel_Nodes_BindParam o, a
        if @block
          @block.call
        else
          super
        end
      end

    end
  end
end
