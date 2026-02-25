# frozen_string_literal: true

require "uri"

# :markup: markdown

module ActionText
  # # Action Text Markdown Conversion
  #
  # Converts an HTML fragment into a Markdown string. Used by `ActionText::Content#to_markdown`
  # and `ActionText::Fragment#to_markdown` to produce Markdown representations of rich text.
  module MarkdownConversion
    extend self

    # Converts a Nokogiri HTML +node+ into a Markdown string.
    #
    #     node = Nokogiri::HTML4.fragment("<p>Hello <strong>world</strong></p>")
    #     MarkdownConversion.node_to_markdown(node) # => "Hello **world**"
    def node_to_markdown(node)
      BottomUpReducer.new(node).reduce do |n, child_values|
        markdown_for_node(n, child_values)
      end.strip
    end

    # Returns a Markdown link: +[title](url)+. Escapes brackets and backslashes
    # in +title+, and percent-encodes characters in +url+ that would break the
    # link syntax.
    #
    #     MarkdownConversion.markdown_link("photo", "https://example.com/photo_(large).png")
    #     # => "[photo](https://example.com/photo_%28large%29.png)"
    def markdown_link(title, url)
      "[#{escape_link_text(title)}](#{encode_href(url)})"
    end

    private
      BOLD_TAGS = %w[b strong].freeze
      ITALIC_TAGS = %w[i em].freeze
      LIST_BULLET = /\A(-|\d+\.) /
      LIST_INDENT = "  "
      ENCODE_HREF_CHARS = /[() <>\n\r\t]/
      private_constant :BOLD_TAGS, :ITALIC_TAGS, :LIST_BULLET, :LIST_INDENT, :ENCODE_HREF_CHARS

      def markdown_for_node(node, child_values)
        if node.text?
          if node.content.blank? && !significant_whitespace?(node)
            ""
          else
            node.content
          end
        elsif node.element?
          method_name = :"visit_#{node.name.tr("-", "_")}"
          if respond_to?(method_name, true)
            send(method_name, node, child_values)
          else
            join_children(child_values).strip
          end
        else
          join_children(child_values)
        end
      end

      def visit_strong(node, child_values)
        inner = join_children(child_values)

        # lexxy redundantly wraps bold subtrees in `<b>`
        if ancestor_named?(node, BOLD_TAGS, max_depth: 4)
          inner
        else
          [ :bold, inner ]
        end
      end
      alias_method :visit_b, :visit_strong

      def visit_em(node, child_values)
        inner = join_children(child_values)

        # lexxy redundantly wraps emphasized subtrees in `<i>`
        if ancestor_named?(node, ITALIC_TAGS, max_depth: 4)
          inner
        else
          [ :italic, inner ]
        end
      end
      alias_method :visit_i, :visit_em

      def visit_s(_node, child_values)
        "~~#{join_children(child_values)}~~"
      end

      def visit_code(node, child_values)
        inner = join_children(child_values)
        if node.parent&.name == "pre"
          inner
        else
          inline_code(inner)
        end
      end

      def visit_pre(_node, child_values)
        inner = join_children(child_values).delete_prefix("\n").delete_suffix("\n")
        fence = code_fence(inner)
        "#{fence}\n#{inner}\n#{fence}\n\n"
      end

      def visit_p(_node, child_values)
        "#{join_children(child_values)}\n\n"
      end

      def visit__heading(_node, child_values, level)
        "#{"#" * level} #{join_children(child_values)}\n\n"
      end
      def visit_h1(node, child_values) = visit__heading(node, child_values, 1)
      def visit_h2(node, child_values) = visit__heading(node, child_values, 2)
      def visit_h3(node, child_values) = visit__heading(node, child_values, 3)
      def visit_h4(node, child_values) = visit__heading(node, child_values, 4)
      def visit_h5(node, child_values) = visit__heading(node, child_values, 5)
      def visit_h6(node, child_values) = visit__heading(node, child_values, 6)

      def visit_blockquote(_node, child_values)
        quoted = join_children(child_values).strip.lines.map { |line| "> #{line}" }.join
        "#{quoted}\n\n"
      end

      def visit_ul(node, child_values)
        items = list_item_lines(node, child_values, prefix: "- ")
        "#{items}\n\n"
      end

      def visit_ol(node, child_values)
        items = list_item_lines(node, child_values, prefix: ->(i) { "#{i + 1}. " })
        "#{items}\n\n"
      end

      def visit_a(node, child_values)
        inner = join_children(child_values)
        if (href = node["href"]) && Rails::HTML::Sanitizer.allowed_uri?(href)
          markdown_link(inner, href)
        else
          inner
        end
      end

      def visit_tr(node, child_values)
        # lexxy does not emit `thead`, so we need to infer header rows from `tr` contents
        if node.element_children.all? { |cell| cell.name == "th" }
          visit__table_header_row(node, child_values)
        else
          cells = child_values_for_elements(node, child_values).map { |v| stringify(v).strip }
          "| #{cells.join(" | ")} |\n"
        end
      end

      def visit_summary(_node, child_values)
        "**#{join_children(child_values)}**\n\n"
      end

      def visit_br(_node, _child_values)
        "\n"
      end

      def visit_hr(_node, _child_values)
        "---\n\n"
      end

      # Avoid including content from elements that aren't meaningful for markdown output
      def visit__unsupported(_node, _child_values)
        ""
      end
      alias_method :visit_script, :visit__unsupported
      alias_method :visit_style, :visit__unsupported

      # These elements pass through their content (parent handlers use child_values directly)
      def visit__passthrough(_node, child_values)
        join_children(child_values)
      end
      alias_method :visit_li, :visit__passthrough
      alias_method :visit_td, :visit__passthrough
      alias_method :visit_th, :visit__passthrough
      alias_method :visit_thead, :visit__passthrough
      alias_method :visit_tbody, :visit__passthrough

      def visit__table_header_row(node, child_values)
        cells = child_values_for_elements(node, child_values).map { |v| stringify(v).strip }
        row = "| #{cells.join(" | ")} |\n"
        separator = "| #{Array.new(cells.size, "---").join(" | ")} |\n"
        "#{row}#{separator}"
      end

      def list_item_lines(list_node, child_values, prefix:)
        element_values = child_values_for_elements(list_node, child_values)
        element_values.each_with_index.filter_map do |value, index|
          text = stringify(value)
          lines = text.split("\n").reject(&:blank?)
          next if lines.empty?

          bullet = prefix.respond_to?(:call) ? prefix.call(index) : prefix
          format_list_item(lines, bullet)
        end.join("\n")
      end

      def format_list_item(lines, bullet)
        first, *rest = lines
        leader = first.match?(LIST_BULLET) ? LIST_INDENT : bullet
        ([ leader + first ] + rest.map { |line| LIST_INDENT + line }).join("\n")
      end

      def join_children(child_values)
        merged = []

        child_values.each do |value|
          # Merge adjacent bold/italic runs which Lexxy emits
          if value.is_a?(Array) && (value[0] == :bold || value[0] == :italic)
            if merged.last.is_a?(Array) && merged.last[0] == value[0]
              merged.last[1] = merged.last[1] + value[1]
            else
              merged << [ value[0], value[1] ]
            end
          else
            merged << value
          end
        end

        parts = merged.map { |v| stringify(v) }
        result = +""
        parts.each do |part|
          # Nested block elements (e.g., lists and blockquotes) need an initial newline injected
          if !result.empty? && !result.end_with?("\n") && part.end_with?("\n\n")
            result << "\n"
          end
          result << part
        end
        result
      end

      def child_values_for_elements(node, child_values)
        node.children.zip(child_values).filter_map do |child, value|
          value if child.element?
        end
      end

      def stringify(value)
        case value
        when Array
          case value[0]
          when :bold then wrap_emphasis(value[1], "**")
          when :italic then wrap_emphasis(value[1], "*")
          else value.join
          end
        else
          value.to_s
        end
      end

      # Make sure `<strong> hello </strong>` becomes ` **hello** ` and not `** hello **`
      # (the latter is not valid markdown).
      def wrap_emphasis(text, marker)
        leading = text[/\A\s*/]
        trailing = text[/\s*\z/]
        inner = text.strip
        "#{leading}#{marker}#{inner}#{marker}#{trailing}"
      end

      def code_fence(content)
        max_run = content.scan(/`{3,}/).map(&:length).max || 0
        "`" * [3, max_run + 1].max
      end

      def inline_code(content)
        max_run = content.scan(/`+/).map(&:length).max || 0
        fence = "`" * [1, max_run + 1].max
        if content.start_with?("`") || content.end_with?("`")
          "#{fence} #{content} #{fence}"
        else
          "#{fence}#{content}#{fence}"
        end
      end

      def significant_whitespace?(node)
        node.previous_sibling&.text? && node.next_sibling&.text?
      end

      def ancestor_named?(node, names, max_depth:)
        current = node.parent
        max_depth.times do
          break unless current&.element?
          return true if current.name.in?(names)
          current = current.parent
        end
        false
      end

      def encode_href(href)
        URI::RFC2396_PARSER.escape(href, ENCODE_HREF_CHARS)
      end

      def escape_link_text(text)
        text.gsub(/[\\\[\]]/) { |c| "\\#{c}" }
      end
  end
end
