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
      # * <tt>content_tag("p", "Hello world!") => <p>Hello world!</p></tt>
      # * <tt>content_tag("div", content_tag("p", "Hello world!"), "class" => "strong") => </tt>
      #   <tt><div class="strong"><p>Hello world!</p></div></tt>
      def content_tag(name, content, options = nil)
        "<#{name}#{tag_options(options.stringify_keys) if options}>#{content}</#{name}>"
      end

      # Returns a CDATA section for the given +content+.  CDATA sections
      # are used to escape blocks of text containing characters which would
      # otherwise be recognized as markup. CDATA sections begin with the string
      # <tt>&lt;![CDATA[</tt> and end with (and may not contain) the string 
      # <tt>]]></tt>. 
      def cdata_section(content)
        "<![CDATA[#{content}]]>"
      end

      private
        def tag_options(options)
          cleaned_options = convert_booleans(options.stringify_keys.reject {|key, value| value.nil?})
          ' ' + cleaned_options.map {|key, value| %(#{key}="#{html_escape(value.to_s)}")}.sort * ' ' unless cleaned_options.empty?
        end

        def convert_booleans(options)
          %w( disabled readonly multiple ).each { |a| boolean_attribute(options, a) }
          options
        end

        def boolean_attribute(options, attribute)
          options[attribute] ? options[attribute] = attribute : options.delete(attribute)
        end
    end
  end
end
