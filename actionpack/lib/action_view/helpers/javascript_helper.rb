require 'action_view/helpers/tag_helper'
require 'action_view/helpers/prototype_helper'

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
    # * Use <tt><%= define_javascript_functions %></tt>: this will copy all the
    #   JavaScript support functions within a single script block. Not
    #   recommended.
    #
    # For documentation on +javascript_include_tag+ see
    # ActionView::Helpers::AssetTagHelper.
    module JavaScriptHelper
      unless const_defined? :JAVASCRIPT_PATH
        JAVASCRIPT_PATH = File.join(File.dirname(__FILE__), 'javascripts')
      end

      include PrototypeHelper

      # Returns a link of the given +name+ that will trigger a JavaScript +function+ using the
      # onclick handler and return false after the fact.
      #
      # The first argument +name+ is used as the link text.
      #
      # The next arguments are optional and may include the javascript function definition and a hash of html_options.
      #
      # The +function+ argument can be omitted in favor of an +update_page+
      # block, which evaluates to a string when the template is rendered
      # (instead of making an Ajax request first).
      #
      # The +html_options+ will accept a hash of html attributes for the link tag. Some examples are :class => "nav_button", :id => "articles_nav_button"
      #
      # Note: if you choose to specify the javascript function in a block, but would like to pass html_options, set the +function+ parameter to nil
      #
      #
      # Examples:
      #   link_to_function "Greeting", "alert('Hello world!')"
      #     Produces:
      #       <a onclick="alert('Hello world!'); return false;" href="#">Greeting</a>
      #
      #   link_to_function(image_tag("delete"), "if (confirm('Really?')) do_delete()")
      #     Produces:
      #       <a onclick="if (confirm('Really?')) do_delete(); return false;" href="#">
      #         <img src="/images/delete.png?" alt="Delete"/>
      #       </a>
      #
      #   link_to_function("Show me more", nil, :id => "more_link") do |page|
      #     page[:details].visual_effect  :toggle_blind
      #     page[:more_link].replace_html "Show me less"
      #   end
      #     Produces:
      #       <a href="#" id="more_link" onclick="try {
      #         $(&quot;details&quot;).visualEffect(&quot;toggle_blind&quot;);
      #         $(&quot;more_link&quot;).update(&quot;Show me less&quot;);
      #       }
      #       catch (e) {
      #         alert('RJS error:\n\n' + e.toString());
      #         alert('$(\&quot;details\&quot;).visualEffect(\&quot;toggle_blind\&quot;);
      #         \n$(\&quot;more_link\&quot;).update(\&quot;Show me less\&quot;);');
      #         throw e
      #       };
      #       return false;">Show me more</a>
      #
      def link_to_function(name, *args, &block)
        html_options = args.extract_options!.symbolize_keys

        function = block_given? ? update_page(&block) : args[0] || ''
        onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function}; return false;"
        href = html_options[:href] || '#'

        content_tag(:a, name, html_options.merge(:href => href, :onclick => onclick))
      end

      # Returns a button with the given +name+ text that'll trigger a JavaScript +function+ using the
      # onclick handler.
      #
      # The first argument +name+ is used as the button's value or display text.
      #
      # The next arguments are optional and may include the javascript function definition and a hash of html_options.
      #
      # The +function+ argument can be omitted in favor of an +update_page+
      # block, which evaluates to a string when the template is rendered
      # (instead of making an Ajax request first).
      #
      # The +html_options+ will accept a hash of html attributes for the link tag. Some examples are :class => "nav_button", :id => "articles_nav_button"
      #
      # Note: if you choose to specify the javascript function in a block, but would like to pass html_options, set the +function+ parameter to nil
      #
      # Examples:
      #   button_to_function "Greeting", "alert('Hello world!')"
      #   button_to_function "Delete", "if (confirm('Really?')) do_delete()"
      #   button_to_function "Details" do |page|
      #     page[:details].visual_effect :toggle_slide
      #   end
      #   button_to_function "Details", :class => "details_button" do |page|
      #     page[:details].visual_effect :toggle_slide
      #   end
      def button_to_function(name, *args, &block)
        html_options = args.extract_options!.symbolize_keys

        function = block_given? ? update_page(&block) : args[0] || ''
        onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function};"

        tag(:input, html_options.merge(:type => 'button', :value => name, :onclick => onclick))
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
        "\n//#{cdata_section("\n#{content}\n//")}\n"
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
