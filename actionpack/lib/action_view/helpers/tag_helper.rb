require 'cgi'
require 'erb'

module ActionView
  module Helpers
    # This is poor man's Builder for the rare cases where you need to programmatically make tags but can't use Builder.
    module TagHelper
      include ERB::Util

      # Examples:
      # * <tt>tag("br") => <br /></tt>
      # * <tt>tag("input", { "type" => "text"}) => <input type="text" /></tt>
      def tag(name, options = nil, open = false)
        "<#{name}#{tag_options(options.stringify_keys) if options}" + (open ? ">" : " />")
      end

      # Examples:
      # * <tt>content_tag(:p, "Hello world!") => <p>Hello world!</p></tt>
      # * <tt>content_tag(:div, content_tag(:p, "Hello world!"), :class => "strong") => </tt>
      #   <tt><div class="strong"><p>Hello world!</p></div></tt>
      #
      # ERb example:
      #  <% content_tag :div, :class => "strong" do -%>
      #    Hello world!
      #  <% end -%>
      #
      # Will output:
      #   <div class="strong"><p>Hello world!</p></div>
      def content_tag(name, content_or_options_with_block = nil, options = nil, &block)
        if block_given?
          options = content_or_options_with_block if content_or_options_with_block.is_a?(Hash)
          content = capture(&block)
          concat(content_tag_string(name, content, options), block.binding)
        else
          content = content_or_options_with_block
          content_tag_string(name, content, options)
        end
      end

      # Returns a CDATA section for the given +content+.  CDATA sections
      # are used to escape blocks of text containing characters which would
      # otherwise be recognized as markup. CDATA sections begin with the string
      # <tt>&lt;![CDATA[</tt> and end with (and may not contain) the string 
      # <tt>]]></tt>. 
      def cdata_section(content)
        "<![CDATA[#{content}]]>"
      end

      # Escapes a given string, while leaving any currently escaped entities alone.
      #
      #   escape_once("1 > 2 &amp; 3")
      #   # => "1 &lt; 2 &amp; 3"
      #
      def escape_once(html)
        fix_double_escape(html_escape(html.to_s))
      end

      private
        def content_tag_string(name, content, options)
          tag_options = options ? tag_options(options.stringify_keys) : ""
          "<#{name}#{tag_options}>#{content}</#{name}>"
        end
      
        def tag_options(options)
          cleaned_options = convert_booleans(options.stringify_keys.reject {|key, value| value.nil?})
          ' ' + cleaned_options.map {|key, value| %(#{key}="#{escape_once(value)}")}.sort * ' ' unless cleaned_options.empty?
        end

        def convert_booleans(options)
          %w( disabled readonly multiple ).each { |a| boolean_attribute(options, a) }
          options
        end

        def boolean_attribute(options, attribute)
          options[attribute] ? options[attribute] = attribute : options.delete(attribute)
        end
        
        # Fix double-escaped entities, such as &amp;amp;, &amp;#123;, etc.
        def fix_double_escape(escaped)
          escaped.gsub(/&amp;([a-z]+|(#\d+));/i) { "&#{$1};" }
        end
    end
  end
end
