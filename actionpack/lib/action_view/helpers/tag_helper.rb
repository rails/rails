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


      # Returns an image tag converting the +options+ instead html options on the tag, but with these special cases:
      #
      # * <tt>:alt</tt>  - If no alt text is given, the file name part of the +src+ is used (capitalized and without the extension)
      # * <tt>:size</tt> - Supplied as "XxY", so "30x45" becomes width="30" and height="45"
      #
      # The +src+ can be supplied as a...
      # * full path, like "/my_images/image.gif"
      # * file name, like "rss.gif", that gets expanded to "/images/rss.gif"
      # * file name without extension, like "logo", that gets expanded to "/images/logo.png"
      def image_tag(src, options = {})
        options.symbolize_keys
  
        options.update({ :src => src.include?("/") ? src : "/images/#{src}" })
        options[:src] += ".png" unless options[:src].include?(".")

        options[:alt] ||= src.split("/").last.split(".").first.capitalize
        
        if options[:size]
          options[:width], options[:height] = options[:size].split("x")
          options.delete :size
        end

        tag("img", options)
      end

      private
        def tag_options(options)
          unless options.empty?
            options.symbolize_keys
            " " + options.map { |key, value|
              %(#{key}="#{html_escape(value.to_s)}")
            }.sort.join(" ")
          end
        end
    end
  end
end