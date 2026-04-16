# frozen_string_literal: true

module ActionText
  class BottomUpReducer # :nodoc:
    def initialize(node)
      @node = node
      @values = {}
    end

    def reduce(&block)
      traverse_bottom_up(@node) do |n|
        child_values = @values.values_at(*n.children)
        @values[n] = block.call(n, child_values)
      end
      @values[@node]
    end

    private
      def traverse_bottom_up(node, &block)
        call_stack, processing_stack = [ node ], []

        until call_stack.empty?
          node = call_stack.pop
          processing_stack.push(node)
          call_stack.concat node.children
        end

        processing_stack.reverse_each(&block)
      end
  end
end
