# frozen_string_literal: true

# :markup: markdown

module ActionText
  module PlainTextConversion
    extend self
    include NodeConversion

    def node_to_plain_text(node)
      BottomUpReducer.new(node).reduce do |n, child_values|
        plain_text_for_node(n, child_values)
      end.then(&method(:remove_trailing_newlines))
    end

    private
      def plain_text_for_node(node, child_values)
        if respond_to?(plain_text_method_for_node(node), true)
          send(plain_text_method_for_node(node), node, child_values)
        else
          plain_text_for_child_values(child_values)
        end
      end

      def plain_text_method_for_node(node)
        :"plain_text_for_#{node.name}_node"
      end

      def plain_text_for_child_values(child_values)
        child_values.join
      end

      def plain_text_for_unsupported_node(node, _child_values)
        ""
      end

      %i[ script style].each do |element|
        alias_method :"plain_text_for_#{element}_node", :plain_text_for_unsupported_node
      end

      def plain_text_for_block(node, child_values)
        "#{remove_trailing_newlines(plain_text_for_child_values(child_values))}\n\n"
      end

      %i[ h1 p ].each do |element|
        alias_method :"plain_text_for_#{element}_node", :plain_text_for_block
      end

      def plain_text_for_list(node, child_values)
        break_if_nested_list(node, plain_text_for_block(node, child_values))
      end

      %i[ ul ol ].each do |element|
        alias_method :"plain_text_for_#{element}_node", :plain_text_for_list
      end

      def plain_text_for_br_node(node, _child_values)
        "\n"
      end

      def plain_text_for_text_node(node, _child_values)
        remove_trailing_newlines(node.text)
      end

      def plain_text_for_div_node(node, child_values)
        "#{remove_trailing_newlines(plain_text_for_child_values(child_values))}\n"
      end

      def plain_text_for_figcaption_node(node, child_values)
        "[#{remove_trailing_newlines(plain_text_for_child_values(child_values))}]"
      end

      def plain_text_for_blockquote_node(node, child_values)
        text = plain_text_for_block(node, child_values)
        return "\u201C\u201D" if text.blank?

        text = text.dup
        text.insert(text.rindex(/\S/) + 1, "\u201D")
        text.insert(text.index(/\S/), "\u201C")
        text
      end

      def plain_text_for_li_node(node, child_values)
        bullet = bullet_for_li_node(node)
        text = remove_trailing_newlines(plain_text_for_child_values(child_values))
        indentation = indentation_for_li_node(node)

        "#{indentation}#{bullet} #{text}\n"
      end

      def bullet_for_li_node(node)
        if list_node_name_for_li_node(node) == "ol"
          index = node.parent.elements.index(node)
          "#{index + 1}."
        else
          "\u2022"
        end
      end
  end
end
