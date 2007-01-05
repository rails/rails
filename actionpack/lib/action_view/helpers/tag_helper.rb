require 'cgi'
require 'erb'

module ActionView
  module Helpers #:nodoc:
    # Use these methods to generate HTML tags programmatically when you can't use
    # a Builder. By default, they output XHTML compliant tags.
    module TagHelper
      include ERB::Util

      # Returns an empty HTML tag of type +name+ which by default is XHTML 
      # compliant. Setting +open+ to true will create an open tag compatible 
      # with HTML 4.0 and below. Add HTML attributes by passing an attributes 
      # hash to +options+. For attributes with no value like (disabled and 
      # readonly), give it a value of true in the +options+ hash. You can use
      # symbols or strings for the attribute names.
      #
      #   tag("br")
      #    # => <br />
      #   tag("br", nil, true)
      #    # => <br>
      #   tag("input", { :type => 'text', :disabled => true }) 
      #    # => <input type="text" disabled="disabled" />
      def tag(name, options = nil, open = false)
        "<#{name}#{tag_options(options) if options}" + (open ? ">" : " />")
      end

      # Returns an HTML block tag of type +name+ surrounding the +content+. Add
      # HTML attributes by passing an attributes hash to +options+. For attributes 
      # with no value like (disabled and readonly), give it a value of true in 
      # the +options+ hash. You can use symbols or strings for the attribute names.
      #
      #   content_tag(:p, "Hello world!")
      #    # => <p>Hello world!</p>
      #   content_tag(:div, content_tag(:p, "Hello world!"), :class => "strong")
      #    # => <div class="strong"><p>Hello world!</p></div>
      #   content_tag("select", options, :multiple => true)
      #    # => <select multiple="multiple">...options...</select>
      #
      # Instead of passing the content as an argument, you can also use a block
      # in which case, you pass your +options+ as the second parameter.
      #
      #   <% content_tag :div, :class => "strong" do -%>
      #     Hello world!
      #   <% end -%>
      #    # => <div class="strong"><p>Hello world!</p></div>
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

      # Returns a CDATA section with the given +content+.  CDATA sections
      # are used to escape blocks of text containing characters which would
      # otherwise be recognized as markup. CDATA sections begin with the string
      # <tt><![CDATA[</tt> and end with (and may not contain) the string <tt>]]></tt>.
      #
      #   cdata_section("<hello world>")
      #    # => <![CDATA[<hello world>]]>
      def cdata_section(content)
        "<![CDATA[#{content}]]>"
      end

      # Returns the escaped +html+ without affecting existing escaped entities.
      #
      #   escape_once("1 > 2 &amp; 3")
      #    # => "1 &lt; 2 &amp; 3"
      def escape_once(html)
        fix_double_escape(html_escape(html.to_s))
      end

      private
        def content_tag_string(name, content, options)
          tag_options = options ? tag_options(options) : ""
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
