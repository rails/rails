module ActionController
  module Testing
    
    # OMG MEGA HAX
    def process_with_test(request, response)
      @_request = request
      @_response = response
      @_response.request = request
      ret = process(request.parameters[:action])
      @_response.body = self.response_body
      @_response.prepare!
      set_test_assigns
      ret
    end
    
    def set_test_assigns
      @assigns = {}
      (instance_variable_names - self.class.protected_instance_variables).each do |var|
        name, value = var[1..-1], instance_variable_get(var)
        @assigns[name] = value
      end
    end
    
  end
end