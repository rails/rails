module ActionController #:nodoc:
  module Components #:nodoc:
    def self.append_features(base)
      super
      base.helper do
        def render_component(options) 
          @controller.logger.info("Start rendering component (#{options.inspect}): ")
          result = @controller.send(:component_response, options).body
          @controller.logger.info("\n\nEnd of component rendering")
          return result
        end
      end
    end

    protected
      def render_component(options = {}) #:doc:
        response = component_response(options)
        logger.info "Rendering component (#{options.inspect}): "
        result = render_text(response.body, response.headers["Status"])
        logger.info("\n\nEnd of component rendering")
        return result
      end
  
    private
      def component_response(options)
        component_class(options).process(component_request(options), @response)
      end
    
      def component_class(options)
        options[:controller] ? (options[:controller].camelize + "Controller").constantize : self.class
      end
      
      def component_request(options)
        component_request = @request.dup
        component_request.send(
          :instance_variable_set, :@parameters, 
          (options[:params] || {}).merge({ "controller" => options[:controller], "action" => options[:action] })
        )
        return component_request
      end
  end
end
