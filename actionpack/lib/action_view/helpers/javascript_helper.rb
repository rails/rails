require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    # Provides functionality for working with JavaScript in your views.
    #
    # == Ajax, controls and visual effects
    #
    # * For information on using Ajax, see
    #   ActionView::Helpers::PrototypeHelper.
    # * For information on using controls and visual effects, see
    #   ActionView::Helpers::ScriptaculousHelper.
    #
    # == Including the JavaScript libraries into your pages
    #
    # Rails includes the Prototype JavaScript framework and the Scriptaculous
    # JavaScript controls and visual effects library.  If you wish to use
    # these libraries and their helpers (ActionView::Helpers::PrototypeHelper
    # and ActionView::Helpers::ScriptaculousHelper), you must do one of the
    # following:
    #
    # * Use <tt><%= javascript_include_tag :defaults %></tt> in the HEAD
    #   section of your page (recommended): This function will return
    #   references to the JavaScript files created by the +rails+ command in
    #   your <tt>public/javascripts</tt> directory. Using it is recommended as
    #   the browser can then cache the libraries instead of fetching all the
    #   functions anew on every request.
    # * Use <tt><%= javascript_include_tag 'prototype' %></tt>: As above, but
    #   will only include the Prototype core library, which means you are able
    #   to use all basic AJAX functionality. For the Scriptaculous-based
    #   JavaScript helpers, like visual effects, autocompletion, drag and drop
    #   and so on, you should use the method described above.
    #
    # For documentation on +javascript_include_tag+ see
    # ActionView::Helpers::AssetTagHelper.
    module JavaScriptHelper
      unless const_defined? :JAVASCRIPT_PATH
        JAVASCRIPT_PATH = File.join(File.dirname(__FILE__), 'javascripts')
      end

      JS_ESCAPE_MAP = {
        '\\'    => '\\\\',
        '</'    => '<\/',
        "\r\n"  => '\n',
        "\n"    => '\n',
        "\r"    => '\n',
        '"'     => '\\"',
        "'"     => "\\'" }

      # Escape carrier returns and single and double quotes for JavaScript segments.
      def escape_javascript(javascript)
        if javascript
          javascript.gsub(/(\\|<\/|\r\n|[\n\r"'])/) { JS_ESCAPE_MAP[$1] }
        else
          ''
        end
      end

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
      # +html_options+ may be a hash of attributes for the <script> tag. Example:
      #   javascript_tag "alert('All is good')", :defer => 'defer'
      #   # => <script defer="defer" type="text/javascript">alert('All is good')</script>
      #
      # Instead of passing the content as an argument, you can also use a block
      # in which case, you pass your +html_options+ as the first parameter.
      #   <% javascript_tag :defer => 'defer' do -%>
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

        tag = content_tag(:script, javascript_cdata_section(content), html_options.merge(:type => Mime::JS))

        if block_called_from_erb?(block)
          concat(tag)
        else
          tag
        end
      end

      def javascript_cdata_section(content) #:nodoc:
        "\n//#{cdata_section("\n#{content}\n//")}\n".html_safe
      end

    protected
      def options_for_javascript(options)
        if options.empty?
          '{}'
        else
          "{#{options.keys.map { |k| "#{k}:#{options[k]}" }.sort.join(', ')}}"
        end
      end

      def array_or_string_for_javascript(option)
        if option.kind_of?(Array)
          "['#{option.join('\',\'')}']"
        elsif !option.nil?
          "'#{option}'"
        end
      end
    end
  end
end
