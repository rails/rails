module ActionController
  module Testing
    extend ActiveSupport::Concern

    include RackConvenience

    # OMG MEGA HAX
    def process_with_new_base_test(request, response)
      @_request = request
      @_response = response
      @_response.request = request
      ret = process(request.parameters[:action])
      @_response.body ||= self.response_body
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

    # TODO : Rewrite tests using controller.headers= to use Rack env
    def headers=(new_headers)
      @_response ||= ActionDispatch::Response.new
      @_response.headers.replace(new_headers)
    end

    module ClassMethods
      def before_filters
        _process_action_callbacks.find_all{|x| x.kind == :before}.map{|x| x.name}
      end
    end
  end
end
