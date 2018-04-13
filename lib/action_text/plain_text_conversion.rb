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
        node.children.each_with_index.map do |child, index|
          plain_text_for_node(child, index)
        end.compact.join("")
      end

      def plain_text_method_for_node(node)
        :"plain_text_for_#{node.name}_node"
      end

      def plain_text_for_block(node, index = 0)
        "#{remove_trailing_newlines(plain_text_for_node_children(node))}\n\n"
      end

      %i[ p ul ol ].each do |element|
        alias_method :"plain_text_for_#{element}_node", :plain_text_for_block
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
        text.sub(/\A(\s*)(.+?)(\s*)\Z/m, '\1“\2”\3')
      end

      def plain_text_for_li_node(node, index)
        bullet = bullet_for_li_node(node, index)
        text = remove_trailing_newlines(plain_text_for_node_children(node))
        "#{bullet} #{text}\n"
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
  end
end
