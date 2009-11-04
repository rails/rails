module ActionView
  module Helpers
    module AjaxHelper
      include UrlHelper

      def remote_form_for(record_or_name_or_array, *args, &proc)
        options = args.extract_options!
        object_name = extract_object_name_for_form!(args, options, record_or_name_or_array)

        concat(form_remote_tag(options))
        fields_for(object_name, *(args << options), &proc)
        concat('</form>'.html_safe!)
      end
      alias_method :form_remote_for, :remote_form_for

      def form_remote_tag(options = {}, &block)
        attributes = {}
        attributes.merge!(extract_remote_attributes!(options))
        attributes.merge!(options)

        url = attributes.delete(:url)
        form_tag(attributes.delete(:action) || url_for(url), attributes, &block)
      end

      def extract_remote_attributes!(options)
        attributes = options.delete(:html) || {}
        
        update = options.delete(:update)
        if update.is_a?(Hash)
          attributes["data-update-success"] = update[:success]
          attributes["data-update-failure"] = update[:failure]
        else
          attributes["data-update-success"] = update
        end

        attributes["data-update-position"] = options.delete(:position)
        attributes["data-method"]          = options.delete(:method)
        attributes["data-js-type"]         = "remote"

        attributes
      end

      def link_to_remote(name, url, options = {})
        attributes = {}
        attributes.merge!(extract_remote_attributes!(options))
        attributes.merge!(options)

        url = url_for(url) if url.is_a?(Hash)
        link_to(name, url, attributes)
      end

      def button_to_remote(name, options = {}, html_options = {})
        attributes = html_options.merge!(:type => "button")
        attributes.merge!(extract_remote_attributes!(options))

        tag(:input, attributes)
      end

      def submit_to_remote(name, value, options = {})
        html_options = options.delete(:html) || {}
        html_options.merge!(:name => name, :value => value, :type => "submit")

        attributes = extract_remote_attributes!(options)
        attributes.merge!(html_options)

        tag(:input, attributes)
      end

      def periodically_call_remote(options = {})
        attributes = extract_observer_attributes!(options)
        attributes["data-js-type"] = "periodical_executer"

        script_decorator(attributes)
      end

      #TODO: Should name change to a css query? - BR
      def observe_field(name, options = {})
        options[:observed] = name
        attributes = extract_observer_attributes!(options)
        attributes["data-js-type"] = "field_observer"

        script_decorator(attributes)
      end

      def observe_field(name, options = {})
        url = options[:url]
        options[:url] = url_for(url) if url && url.is_a?(Hash)
        
        frequency = options.delete(:frequency)
        if frequency && frequency != 0
          options[:frequency] = frequency.to_i
        end

        if with = options[:with]
          if with !~ /[\{=(.]/
            options[:with] = "'#{options[:with]}=' + encodeURIComponent(value)"
          else
            options[:with] ||= 'value' unless options[:function]
          end
        end

        if function = options[:function]
          statements = function # || remote_function(options) # TODO: Need to implement remote function - BR
          options[:function] = JSFunction.new(statements, "element", "value")
        end
        options[:name] = name

        script_decorator("field_observer", options)
      end

      def script_decorator(js_type, options)
        attributes = [%(type="application/json"), %(data-js-type="#{js_type}")]
        attributes += options.map{|k, v| %(data-#{k}="#{v}")}
        "<script " + attributes.join(" ") + "></script>"
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

      private

      # TODO: Move to javascript helpers - BR
      class JSFunction
        def initialize(statements, *arguments)
          @statements, @arguments = statements, arguments
        end

        def to_s(options = nil)
          "function(#{@arguments.join(", ")}) {#{@statements}}"
        end
      end

    end
  end
end
