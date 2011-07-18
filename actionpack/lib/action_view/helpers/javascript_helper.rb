require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    module JavaScriptHelper
      JS_ESCAPE_MAP = {
        '\\'    => '\\\\',
        '</'    => '<\/',
        "\r\n"  => '\n',
        "\n"    => '\n',
        "\r"    => '\n',
        '"'     => '\\"',
        "'"     => "\\'" }

      # Escape carrier returns and single and double quotes for JavaScript segments.
      # Also available through the alias j(). This is particularly helpful in JavaScript responses, like:
      #
      #   $('some_element').replaceWith('<%=j render 'some/element_template' %>');
      def escape_javascript(javascript)
        if javascript
          result = javascript.gsub(/(\\|<\/|\r\n|[\n\r"'])/) {|match| JS_ESCAPE_MAP[match] }
          javascript.html_safe? ? result.html_safe : result
        else
          ''
        end
      end

      alias_method :j, :escape_javascript

      # Returns a JavaScript tag with the +content+ inside. Example:
      #   javascript_tag "alert('All is good')"
      #
      # Returns:
      #   <script type="text/javascript">
      #   //<![CDATA[
      #   alert('All is good')
      #   //]]>
      #   </script>
      #
      # +html_options+ may be a hash of attributes for the <tt>\<script></tt>
      # tag. Example:
      #   javascript_tag "alert('All is good')", :defer => 'defer'
      #   # => <script defer="defer" type="text/javascript">alert('All is good')</script>
      #
      # Instead of passing the content as an argument, you can also use a block
      # in which case, you pass your +html_options+ as the first parameter.
      #   <%= javascript_tag :defer => 'defer' do -%>
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

        content_tag(:script, javascript_cdata_section(content), html_options.merge(:type => Mime::JS))
      end

      def javascript_cdata_section(content) #:nodoc:
        "\n//#{cdata_section("\n#{content}\n//")}\n".html_safe
      end

      # Returns a button whose +onclick+ handler triggers the passed JavaScript.
      #
      # The helper receives a name, JavaScript code, and an optional hash of HTML options. The
      # name is used as button label and the JavaScript code goes into its +onclick+ attribute.
      # If +html_options+ has an <tt>:onclick</tt>, that one is put before +function+.
      #
      #   button_to_function "Greeting", "alert('Hello world!')", :class => "ok"
      #   # => <input class="ok" onclick="alert('Hello world!');" type="button" value="Greeting" />
      #
      def button_to_function(name, function=nil, html_options={})
        onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function};"

        tag(:input, html_options.merge(:type => 'button', :value => name, :onclick => onclick))
      end

      # Returns a link whose +onclick+ handler triggers the passed JavaScript.
      #
      # The helper receives a name, JavaScript code, and an optional hash of HTML options. The
      # name is used as the link text and the JavaScript code goes into the +onclick+ attribute.
      # If +html_options+ has an <tt>:onclick</tt>, that one is put before +function+. Once all
      # the JavaScript is set, the helper appends "; return false;".
      #
      # The +href+ attribute of the tag is set to "#" unles +html_options+ has one.
      #
      #   link_to_function "Greeting", "alert('Hello world!')", :class => "nav_link"
      #   # => <a class="nav_link" href="#" onclick="alert('Hello world!'); return false;">Greeting</a>
      #
      def link_to_function(name, function, html_options={})
        onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function}; return false;"
        href = html_options[:href] || '#'

        content_tag(:a, name, html_options.merge(:href => href, :onclick => onclick))
      end
    end
  end
end
