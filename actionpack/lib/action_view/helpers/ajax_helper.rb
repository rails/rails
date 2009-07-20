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