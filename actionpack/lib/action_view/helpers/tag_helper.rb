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
      def tag(name, options = {}, open = false)
        "<#{name}#{tag_options(options)}" + (open ? ">" : " />")
      end

      # Examples:
      # * <tt>content_tag("p", "Hello world!") => <p>Hello world!</p></tt>
      # * <tt>content_tag("div", content_tag("p", "Hello world!"), "class" => "strong") => </tt>
      #   <tt><div class="strong"><p>Hello world!</p></div></tt>
      def content_tag(name, content, options = {})
        "<#{name}#{tag_options(options)}>#{content}</#{name}>"
      end

      private
        def tag_options(options)
          cleaned_options = options.reject { |key, value| value.nil? }
          unless cleaned_options.empty?
            " " + cleaned_options.symbolize_keys.map { |key, value|
              %(#{key}="#{html_escape(value.to_s)}")
            }.sort.join(" ")
          end
        end
    end
  end
end