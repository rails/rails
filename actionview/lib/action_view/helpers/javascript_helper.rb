# frozen_string_literal: true

require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers #:nodoc:
    module JavaScriptHelper
      JS_ESCAPE_MAP = {
        '\\'    => '\\\\',
        '</'    => '<\/',
        "\r\n"  => '\n',
        "\n"    => '\n',
        "\r"    => '\n',
        '"'     => '\\"',
        "'"     => "\\'",
        '`'     => '\\`',
        '$'     => '\\$'
      }

      JS_ESCAPE_MAP[(+"\342\200\250").force_encoding(Encoding::UTF_8).encode!] = '&#x2028;'
      JS_ESCAPE_MAP[(+"\342\200\251").force_encoding(Encoding::UTF_8).encode!] = '&#x2029;'

      # Escapes carriage returns and single and double quotes for JavaScript segments.
      #
      # Also available through the alias j(). This is particularly helpful in JavaScript
      # responses, like:
      #
      #   $('some_element').replaceWith('<%= j render 'some/element_template' %>');
      def escape_javascript(javascript)
        javascript = javascript.to_s
        if javascript.empty?
          result = ''
        else
          result = javascript.gsub(/(\\|<\/|\r\n|\342\200\250|\342\200\251|[\n\r"']|[`]|[$])/u, JS_ESCAPE_MAP)
        end
        javascript.html_safe? ? result.html_safe : result
      end

      alias_method :j, :escape_javascript

      # Returns a JavaScript tag with the +content+ inside. Example:
      #   javascript_tag "alert('All is good')"
      #
      # Returns:
      #   <script>
      #   //<![CDATA[
      #   alert('All is good')
      #   //]]>
      #   </script>
      #
      # +html_options+ may be a hash of attributes for the <tt>\<script></tt>
      # tag.
      #
      #   javascript_tag "alert('All is good')", type: 'application/javascript'
      #
      # Returns:
      #   <script type="application/javascript">
      #   //<![CDATA[
      #   alert('All is good')
      #   //]]>
      #   </script>
      #
      # Instead of passing the content as an argument, you can also use a block
      # in which case, you pass your +html_options+ as the first parameter.
      #
      #   <%= javascript_tag type: 'application/javascript' do -%>
      #     alert('All is good')
      #   <% end -%>
      #
      # If you have a content security policy enabled then you can add an automatic
      # nonce value by passing <tt>nonce: true</tt> as part of +html_options+. Example:
      #
      #   <%= javascript_tag nonce: true do -%>
      #     alert('All is good')
      #   <% end -%>
      def javascript_tag(content_or_options_with_block = nil, html_options = {}, &block)
        content =
          if block_given?
            html_options = content_or_options_with_block if content_or_options_with_block.is_a?(Hash)
            capture(&block)
          else
            content_or_options_with_block
          end

        if html_options[:nonce] == true
          html_options[:nonce] = content_security_policy_nonce
        end

        content_tag('script', javascript_cdata_section(content), html_options)
      end

      def javascript_cdata_section(content) #:nodoc:
        "\n//#{cdata_section("\n#{content}\n//")}\n".html_safe
      end
    end
  end
end
