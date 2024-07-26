require 'cgi'

module ActionView
  module Helpers
    module TagHelper
      def tag(name, options, open = false)
        "<#{name + tag_options(options)}" + (open ? ">" : " />")
      end
      
      def content_tag(name, content, options)
        "<#{name + tag_options(options)}>#{content}</#{name}>"
      end

      def form_tag(url_for_options, options = {}, *parameters_for_url)
        html_options = { "method" => "POST" }.merge(options)
        
        if html_options[:multipart]
          html_options["enctype"] = "multipart/form-data"
          html_options.delete(:multipart)
        end
        
        html_options["action"] = url_for(url_for_options, *parameters_for_url)
        
        tag("form", html_options, true)
      end
      
      alias_method :start_form_tag, :form_tag

      def end_form_tag
        "</form>"
      end


      private
        def tag_options(options)
          " " + options.collect { |pair| "#{pair.first}=\"#{html_escape(pair.last)}\"" }.sort.join(" ") unless options.empty?
        end

        def html_escape(value)
          CGI.escapeHTML(value.to_s)
        end
    end
  end
end