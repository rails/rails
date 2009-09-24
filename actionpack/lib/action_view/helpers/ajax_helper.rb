module ActionView
  module Helpers
    module AjaxHelper
      include UrlHelper
      
      def link_to_remote(name, url, options = {})
        html = options.delete(:html) || {}
        
        update = options.delete(:update)
        if update.is_a?(Hash)
          html["data-update-success"] = update[:success]
          html["data-update-failure"] = update[:failure]
        else
          html["data-update-success"] = update
        end

        html["data-update-position"] = options.delete(:position)
        html["data-method"]          = options.delete(:method)
        html["data-remote"]          = "true"
        
        html.merge!(options)

        url = url_for(url) if url.is_a?(Hash)
        link_to(name, url, html)
      end
      
      def button_to_remote(name, options = {}, html_options = {})
        url = options.delete(:url)
        url = url_for(url) if url.is_a?(Hash)
        
        html_options.merge!(:type => "button", :value => name,
          :"data-url" => url)
        
        tag(:input, html_options)
      end

      def observe_field(name, options = {})
        if options[:url]
          options[:url] = options[:url].is_a?(Hash) ? url_for(options[:url]) : options[:url]
        end
        
        if options[:frequency]
          case options[:frequency]
            when 0
              options.delete(:frequency)
            else
              options[:frequency] = options[:frequency].to_i
          end
        end

        if options[:with] && (options[:with] !~ /[\{=(.]/)
          options[:with] = "'#{options[:with]}=' + encodeURIComponent(value)"
        else
          options[:with] ||= 'value' unless options[:function]
        end

        if options[:function]
          statements = options[:function] # || remote_function(options) # TODO: Need to implement remote function - BR
          options[:function] = JSFunction.new(statements, "element", "value")
        end

        options[:name] = name

        <<-SCRIPT
        <script type="application/json" data-rails-type="observe_field">
        //<![CDATA[
          #{options.to_json}
        // ]]>
        </script>
        SCRIPT
      end

      # TODO: Move to javascript helpers - BR
      class JSFunction
        def initialize(statements, *arguments)
          @statements, @arguments = statements, arguments
        end

        def as_json(options = nil)
          "function(#{@arguments.join(", ")}) {#{@statements}}"
        end
      end

      module Rails2Compatibility
        def set_callbacks(options, html)
          [:complete, :failure, :success, :interactive, :loaded, :loading].each do |type|
            html["data-#{type}-code"]  = options.delete(type.to_sym)
          end

          options.each do |option, value|
            if option.is_a?(Integer)
              html["data-#{option}-code"] = options.delete(option)
            end
          end
        end
        
        def link_to_remote(name, url, options = nil)
          if !options && url.is_a?(Hash) && url.key?(:url)
            url, options = url.delete(:url), url
          end
          
          set_callbacks(options, options[:html] ||= {})
          
          super
        end
        
        def button_to_remote(name, options = {}, html_options = {})
          set_callbacks(options, html_options)
          super
        end
      end
      
    end
  end
end