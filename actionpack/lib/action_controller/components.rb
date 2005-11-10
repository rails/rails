module ActionController #:nodoc:
  # Components allows you to call other actions for their rendered response while executing another action. You can either delegate
  # the entire response rendering or you can mix a partial response in with your other content.
  #
  #   class WeblogController < ActionController::Base
  #     # Performs a method and then lets hello_world output its render
  #     def delegate_action
  #       do_other_stuff_before_hello_world
  #       render_component :controller => "greeter",  :action => "hello_world", :params => { "person" => "david" }
  #     end
  #   end
  #
  #   class GreeterController < ActionController::Base
  #     def hello_world
  #       render_text "#{@params['person']} says, Hello World!"
  #     end
  #   end
  #
  # The same can be done in a view to do a partial rendering:
  # 
  #   Let's see a greeting: 
  #   <%= render_component :controller => "greeter", :action => "hello_world" %>
  module Components
    def self.append_features(base) #:nodoc:
      super
      base.helper do
        def render_component(options) 
          @controller.send(:render_component_as_string, options)
        end
      end
    end

    protected
      # Renders the component specified as the response for the current method
      def render_component(options = {}) #:doc:
        component_logging(options) { render_text(component_response(options).body, response.headers["Status"]) }
      end

      # Returns the component response as a string
      def render_component_as_string(options) #:doc:
        component_logging(options) do
          response = component_response(options, false)
          unless response.redirected_to.nil?
            render_component_as_string response.redirected_to
          else
            response.body
          end
       end
      end
  
    private
      def component_response(options, reuse_response = true)
        begin
          ActionController::Flash::FlashHash.avoid_sweep = true
          p = component_class(options).process(request_for_component(options), reuse_response ? @response : response_for_component)
        ensure
          ActionController::Flash::FlashHash.avoid_sweep = false
        end
        p
      end
    
      def component_class(options)
        options[:controller] ? (options[:controller].camelize + "Controller").constantize : self.class
      end
      
      def request_for_component(options)
        request_for_component = @request.dup
        request_for_component.send(
          :instance_variable_set, :@parameters, 
          (options[:params] || {}).merge({ "controller" => options[:controller], "action" => options[:action], "id" => options[:id] }).with_indifferent_access
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
