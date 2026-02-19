# frozen_string_literal: true

# :markup: markdown

module ActionText
  module NodeConversion
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

    private
      def remove_trailing_newlines(text)
        text.chomp("")
      end

      def list_node_name_for_li_node(node)
        node.ancestors.lazy.map(&:name).grep(/^[uo]l$/).first
      end

      def indentation_for_li_node(node)
        depth = list_node_depth_for_node(node)
        if depth > 1
          "  " * (depth - 1)
        end
      end

      def list_node_depth_for_node(node)
        node.ancestors.map(&:name).grep(/^[uo]l$/).count
      end

      def break_if_nested_list(node, text)
        if list_node_depth_for_node(node) > 0
          "\n#{text}"
        else
          text
        end
      end
  end
end
