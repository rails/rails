# frozen_string_literal: true

# :markup: markdown

module ActionText
  module PlainTextConversion
    extend self

    def node_to_plain_text(node)
      remove_trailing_newlines(plain_text_for_node(node))
    end

    private
      def plain_text_for_node(node, index = 0)
        if respond_to?(plain_text_method_for_node(node), true)
          send(plain_text_method_for_node(node), node, index)
        else
          plain_text_for_node_children(node)
        end
      end

      def plain_text_for_node_children(node)
        texts = []
        node.children.each_with_index do |child, index|
          next if skippable?(child)

          texts << plain_text_for_node(child, index)
        end
        texts.join
      end

      def skippable?(node)
        node.name == "script" || node.name == "style"
      end

      def plain_text_method_for_node(node)
        :"plain_text_for_#{node.name}_node"
      end

      def plain_text_for_block(node, index = 0)
        "#{remove_trailing_newlines(plain_text_for_node_children(node))}\n\n"
      end

      %i[ h1 p ].each do |element|
        alias_method :"plain_text_for_#{element}_node", :plain_text_for_block
      end

      def plain_text_for_list(node, index)
        "#{break_if_nested_list(node, plain_text_for_block(node))}"
      end

      %i[ ul ol ].each do |element|
        alias_method :"plain_text_for_#{element}_node", :plain_text_for_list
      end

      def plain_text_for_br_node(node, index)
        "\n"
      end

      def plain_text_for_text_node(node, index)
        remove_trailing_newlines(node.text)
      end

      def plain_text_for_div_node(node, index)
        "#{remove_trailing_newlines(plain_text_for_node_children(node))}\n"
      end

      def plain_text_for_figcaption_node(node, index)
        "[#{remove_trailing_newlines(plain_text_for_node_children(node))}]"
      end

      def plain_text_for_blockquote_node(node, index)
        text = plain_text_for_block(node)
        return "“”" if text.blank?

        text = text.dup
        text.insert(text.rindex(/\S/) + 1, "”")
        text.insert(text.index(/\S/), "“")
        text
      end

      def plain_text_for_li_node(node, index)
        bullet = bullet_for_li_node(node, index)
        text = remove_trailing_newlines(plain_text_for_node_children(node))
        indentation = indentation_for_li_node(node)

        "#{indentation}#{bullet} #{text}\n"
      end

      def remove_trailing_newlines(text)
        text.chomp("")
      end

      def bullet_for_li_node(node, index)
        if list_node_name_for_li_node(node) == "ol"
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
  end
end
