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

      def visit_Arel_Nodes_Assignment o
        if o.right.is_a? Arel::Nodes::BindParam
          "#{visit o.left} = #{visit o.right}"
        else
          super
        end
      end

      def visit_Arel_Nodes_BindParam o
        if @block
          @block.call
        else
          super
        end
      end
      
    end
  end
end
