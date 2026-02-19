# frozen_string_literal: true

# :markup: markdown

module ActionText
  module MarkdownConversion
    extend self
    include NodeConversion

    def node_to_markdown(node)
      BottomUpReducer.new(node).reduce do |n, child_values|
        markdown_for_node(n, child_values)
      end.then(&method(:remove_trailing_newlines))
    end

    private
      def markdown_for_node(node, child_values)
        if respond_to?(markdown_method_for_node(node), true)
          send(markdown_method_for_node(node), node, child_values)
        else
          markdown_for_child_values(child_values)
        end
      end

      def markdown_method_for_node(node)
        :"markdown_for_#{node.name}_node"
      end

      def markdown_for_child_values(child_values)
        child_values.join
      end

      def markdown_for_unsupported_node(node, _child_values)
        ""
      end

      %i[ script style ].each do |element|
        alias_method :"markdown_for_#{element}_node", :markdown_for_unsupported_node
      end

      def markdown_for_block(node, child_values)
        "#{remove_trailing_newlines(markdown_for_child_values(child_values))}\n\n"
      end

      alias_method :markdown_for_p_node, :markdown_for_block

      def markdown_for_heading_node(node, child_values)
        level = node.name[1].to_i
        prefix = "#" * level
        "#{prefix} #{remove_trailing_newlines(markdown_for_child_values(child_values))}\n\n"
      end

      %i[ h1 h2 h3 h4 h5 h6 ].each do |element|
        alias_method :"markdown_for_#{element}_node", :markdown_for_heading_node
      end

      def markdown_for_list(node, child_values)
        break_if_nested_list(node, markdown_for_block(node, child_values))
      end

      %i[ ul ol ].each do |element|
        alias_method :"markdown_for_#{element}_node", :markdown_for_list
      end

      def markdown_for_br_node(node, _child_values)
        "\n"
      end

      def markdown_for_text_node(node, _child_values)
        escape_markdown_chars(remove_trailing_newlines(node.text))
      end

      def escape_markdown_chars(text)
        text.gsub(/(?=[\\*_`~])/, "\\")
      end

      def markdown_for_div_node(node, child_values)
        "#{remove_trailing_newlines(markdown_for_child_values(child_values))}\n"
      end

      def markdown_for_figcaption_node(node, child_values)
        "[#{remove_trailing_newlines(markdown_for_child_values(child_values))}]"
      end

      def markdown_for_blockquote_node(node, child_values)
        text = remove_trailing_newlines(markdown_for_child_values(child_values))
        return "" if text.blank?

        text.lines.map { |line| "> #{line.chomp}\n" }.join + "\n"
      end

      def markdown_for_li_node(node, child_values)
        bullet = bullet_for_li_node(node)
        text = remove_trailing_newlines(markdown_for_child_values(child_values))
        indentation = indentation_for_li_node(node)

        "#{indentation}#{bullet} #{text}\n"
      end

      def markdown_for_strong_node(node, child_values)
        wrap_inline_markup(markdown_for_child_values(child_values), "**")
      end

      alias_method :markdown_for_b_node, :markdown_for_strong_node

      def markdown_for_em_node(node, child_values)
        wrap_inline_markup(markdown_for_child_values(child_values), "*")
      end

      alias_method :markdown_for_i_node, :markdown_for_em_node

      def markdown_for_del_node(node, child_values)
        wrap_inline_markup(markdown_for_child_values(child_values), "~~")
      end

      alias_method :markdown_for_s_node, :markdown_for_del_node

      def markdown_for_a_node(node, child_values)
        href = node["href"]
        text = markdown_for_child_values(child_values)
        if href.present?
          "[#{text}](#{href})"
        else
          text
        end
      end

      def markdown_for_pre_node(node, child_values)
        "```\n#{remove_trailing_newlines(markdown_for_child_values(child_values))}\n```\n\n"
      end

      def markdown_for_code_node(node, child_values)
        if node.parent&.name == "pre"
          markdown_for_child_values(child_values)
        else
          "`#{markdown_for_child_values(child_values)}`"
        end
      end

      def markdown_for_hr_node(node, _child_values)
        "---\n\n"
      end

      def bullet_for_li_node(node)
        if list_node_name_for_li_node(node) == "ol"
          index = node.parent.elements.index(node)
          "#{index + 1}."
        else
          "-"
        end
      end

      # Wraps text with inline Markdown markers (e.g. **, *, ~~),
      # moving any leading/trailing whitespace outside the markers
      # so the output is valid Markdown.
      def wrap_inline_markup(text, marker)
        return text if text.blank?

        text.match(/\A(\s*)(.*\S)(\s*)\z/m) do |m|
          "#{m[1]}#{marker}#{m[2]}#{marker}#{m[3]}"
        end || text
      end
  end
end
