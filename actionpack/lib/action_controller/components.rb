module ActionController #:nodoc:
  # TODO: Cookies and session variables set in render_component that happens inside a view should be copied over.
  module Components #:nodoc:
    def self.append_features(base)
      super
      base.helper do
        def render_component(options) 
          @controller.send(:render_component_as_string, options)
        end
      end
    end

    protected
      def render_component(options = {}) #:doc:
        component_logging(options) { render_text(component_response(options).body, response.headers["Status"]) }
      end

      def render_component_as_string(options) #:doc:
        component_logging(options) { component_response(options, false).body }
      end
  
    private
      def component_response(options, reuse_response = true)
        component_class(options).process(request_for_component(options), reuse_response ? @response : response_for_component)
      end
    
      def component_class(options)
        options[:controller] ? (options[:controller].camelize + "Controller").constantize : self.class
      end
      
      def request_for_component(options)
        request_for_component = @request.dup
        request_for_component.send(
          :instance_variable_set, :@parameters, 
          (options[:params] || {}).merge({ "controller" => options[:controller], "action" => options[:action] })
        )
        return request_for_component
      end
      
      def response_for_component
        @response.dup
      end
      
      def component_logging(options)
        logger.info("Start rendering component (#{options.inspect}): ") unless logger.nil?
        result = yield
        logger.info("\n\nEnd of component rendering") unless logger.nil?
        return result
      end
  end
end
