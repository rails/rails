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

      # Starts a form tag that points the action to an url configured with <tt>url_for_options</tt> just like 
      # ActionController::Base#url_for.
      def form_tag(url_for_options = {}, options = {}, *parameters_for_url)
        html_options = { "method" => "post" }.merge(options)
        
        if html_options[:multipart]
          html_options["enctype"] = "multipart/form-data"
          html_options.delete(:multipart)
        end
        
        html_options["action"] = url_for(url_for_options, *parameters_for_url)
        
        tag("form", html_options, true)
      end
      
      alias_method :start_form_tag, :form_tag

      # Outputs "</form>"
      def end_form_tag
        "</form>"
      end


      private
        def tag_options(options)
          unless options.empty?
            " " + options.map { |key, value|
              %(#{key}="#{html_escape(value)}")
            }.sort.join(" ")
          end
        end
    end
  end
end
