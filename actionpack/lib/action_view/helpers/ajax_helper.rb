module ActionView
  module Helpers
    module AjaxHelper
      include UrlHelper

      def extract_remote_attributes!(options)
        attributes = options.delete(:html) || {}

        attributes.merge!(extract_update_attributes!(options))
        attributes.merge!(extract_request_attributes!(options))
        attributes["data-js-type"] = options.delete(:js_type) || "remote"

        attributes
      end

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

        url = attributes.delete("data-url")
        form_tag(attributes.delete(:action) || url, attributes, &block)
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

      def observe_field(name, options = {}, html_options = {})
        url = options.delete(:url)
        url = url_for(url) if url.is_a?(Hash)

        if frequency = options.delete(:frequency)
          html_options[:"data-frequency"] = frequency
        end

        html_options.merge!(:"data-observe" => true, :"data-url" => url)
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

      private

      def extract_request_attributes!(options)
        attributes = {}
        attributes["data-method"] = options.delete(:method)

        url = options.delete(:url)
        attributes["data-url"] = url.is_a?(Hash) ? url_for(url) : url

        #TODO: Remove all references to prototype - BR
        if options.delete(:form)
          attributes["data-parameters"] = 'Form.serialize(this)'
        elsif submit = options.delete(:submit)
          attributes["data-parameters"] = "Form.serialize('#{submit}')"
        elsif with = options.delete(:with)
          if with !~ /[\{=(.]/
            attributes["data-with"] = "'#{with}=' + encodeURIComponent(value)"
          else
            attributes["data-with"] = with
          end
        end

        purge_unused_attributes!(attributes)
      end

      def extract_update_attributes!(options)
        attributes = {}
        update = options.delete(:update)
        if update.is_a?(Hash)
          attributes["data-update-success"] = update[:success]
          attributes["data-update-failure"] = update[:failure]
        else
          attributes["data-update-success"] = update
        end
        attributes["data-update-position"] = options.delete(:position)

        purge_unused_attributes!(attributes)
      end

      def extract_observer_attributes!(options)
        attributes = extract_remote_attributes!(options)
        attributes["data-observed"] = options.delete(:observed)

        callback = options.delete(:function)
        frequency = options.delete(:frequency)
        if callback
          attributes["data-observer-code"] = create_js_function(callback, "element", "value")
        end
        if frequency && frequency != 0
          attributes["data-frequency"] = frequency.to_i
        end

        purge_unused_attributes!(attributes)
      end

      def purge_unused_attributes!(attributes)
        attributes.delete_if {|key, value| value.nil? }
        attributes
      end

      def create_js_function(statements, *arguments)
        "function(#{arguments.join(", ")}) {#{statements}}"
      end

    end
  end
end
