# frozen_string_literal: true

# :markup: markdown
module ActionText
  class BottomUpReducer # :nodoc:
    def initialize(node)
      @node = node
      @values = {}
    end

    def reduce(&block)
      traverse_bottom_up(@node) do |n, children|
        @values[n] = block.call(n, children.map { |child| @values[child] })
      end
      @values[@node]
    end

    private
      def traverse_bottom_up(node)
        call_stack, processing_stack, children_stack = [ node ], [], []

        until call_stack.empty?
          node = call_stack.pop
          children = node.children.to_a
          processing_stack.push(node)
          children_stack.push(children)
          call_stack.concat children
        end

        (processing_stack.size - 1).downto(0) do |i|
          yield processing_stack[i], children_stack[i]
        end
      end
  end
end
