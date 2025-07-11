# frozen_string_literal: true

# :markup: markdown

module ActionText
  module PlainTextConversion
    extend self

    def node_to_plain_text(node)
      remove_trailing_newlines(node_to_plain_text_content_tree(node).content)
    end

    private
      def node_to_plain_text_content_tree(node)
        BottomUpReplacer.replace_content(node.dup) { |n| plain_text_for_node(n) }
      end

      def plain_text_for_node(node)
        if respond_to?(plain_text_method_for_node(node), true)
          send(plain_text_method_for_node(node), node)
        else
          plain_text_for_node_children(node)
        end
      end

      def plain_text_for_node_children(node)
        node.children.map(&:content).join
      end

      def plain_text_method_for_node(node)
        :"plain_text_for_#{node.name}_node"
      end

      def plain_text_for_unsupported_node(node)
        ""
      end

      %i[ script style].each do |element|
        alias_method :"plain_text_for_#{element}_node", :plain_text_for_unsupported_node
      end

      def plain_text_for_block(node)
        "#{remove_trailing_newlines(plain_text_for_node_children(node))}\n\n"
      end

      %i[ h1 p ].each do |element|
        alias_method :"plain_text_for_#{element}_node", :plain_text_for_block
      end

      def plain_text_for_list(node)
        "#{break_if_nested_list(node, plain_text_for_block(node))}"
      end

      %i[ ul ol ].each do |element|
        alias_method :"plain_text_for_#{element}_node", :plain_text_for_list
      end

      def plain_text_for_br_node(node)
        "\n"
      end

      def plain_text_for_text_node(node)
        remove_trailing_newlines(node.text)
      end

      def plain_text_for_div_node(node)
        "#{remove_trailing_newlines(plain_text_for_node_children(node))}\n"
      end

      def plain_text_for_figcaption_node(node)
        "[#{remove_trailing_newlines(plain_text_for_node_children(node))}]"
      end

      def plain_text_for_blockquote_node(node)
        text = plain_text_for_block(node)
        return "“”" if text.blank?

        text = text.dup
        text.insert(text.rindex(/\S/) + 1, "”")
        text.insert(text.index(/\S/), "“")
        text
      end

      def plain_text_for_li_node(node)
        bullet = bullet_for_li_node(node)
        text = remove_trailing_newlines(plain_text_for_node_children(node))
        indentation = indentation_for_li_node(node)

        "#{indentation}#{bullet} #{text}\n"
      end

      def remove_trailing_newlines(text)
        text.chomp("")
      end

      def bullet_for_li_node(node)
        if list_node_name_for_li_node(node) == "ol"
          index = node.parent.elements.index(node)
          "#{index + 1}."
        else
          "•"
        end
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

      class BottomUpReplacer
        def self.replace_content(node, &block)
          new(node).replace_content(&block)
        end

        def initialize(node)
          @node = node
        end

        def replace_content(&block)
          @node.tap do |node|
            traverse_bottom_up(node) do |n|
              n.content = block.call(n)
            end
          end
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
end
