module ActionController #:nodoc:
  module Components #:nodoc:
    def self.append_features(base)
      super
      base.helper { def render_component(options) @controller.send(:component_response, options).body end }
    end

    protected
      def render_component(options = {}) #:doc:
        response = component_response(options)
        render_text(response.body, response.response_code)
      end
  
    private
      def component_response(options)
        component_class(options).process(component_request(options), @response)
      end
    
      def component_class(options)
        options[:controller] ? (options[:controller].camelize + "Controller").constantize : self
      end
      
      def component_request(options)
        component_request = @request.dup
        component_request.send(:instance_variable_set, :@parameters, options[:params].merge({ "controller" => options[:controller], "action" => options[:action] }))
        component_request
      end
  end
end
