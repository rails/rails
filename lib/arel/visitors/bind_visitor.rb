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
