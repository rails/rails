require 'cgi'

module ActionView
  module Helpers
    # This is poor man's Builder for the rare cases where you need to programmatically make tags but can't use Builder.
    module TagHelper
      include ERB::Util

      # Examples: 
      # * tag("br") => <br />
      # * tag("input", { "type" => "text"}) => <input type="text" />
      def tag(name, options = {}, open = false)
        "<#{name + tag_options(options)}" + (open ? ">" : " />")
      end
      
      # Examples: 
      # * content_tag("p", "Hello world!") => <p>Hello world!</p>
      # * content_tag("div", content_tag("p", "Hello world!"), "class" => "strong") => 
      #   <div class="strong"><p>Hello world!</p></div>
      def content_tag(name, content, options = {})
        "<#{name + tag_options(options)}>#{content}</#{name}>"
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
          if options.empty?
            ""
          else
            " " + options.collect { |pair| 
              "#{pair.first}=\"#{html_escape(pair.last)}\"" 
            }.sort.join(" ") 
          end
        end
    end
  end
end
