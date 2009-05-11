module ActionController
  class AbstractBase < AbstractController::Base
    
    # :api: public
    attr_internal :request, :response, :params

    # :api: public
    def self.controller_name
      @controller_name ||= controller_path.split("/").last
    end

    # :api: public
    def controller_name() self.class.controller_name end

    # :api: public    
    def self.controller_path
      @controller_path ||= self.name.sub(/Controller$/, '').underscore
    end
    
    # :api: public    
    def controller_path() self.class.controller_path end
      
    # :api: private      
    def self.action_methods
      @action_names ||= Set.new(self.public_instance_methods - self::CORE_METHODS)
    end
    
    # :api: private    
    def self.action_names() action_methods end
    
    # :api: private        
    def action_methods() self.class.action_names end

    # :api: private
    def action_names() action_methods end
    
    # :api: plugin
    def self.call(env)
      controller = new
      controller.call(env).to_rack
    end
    
    # :api: plugin
    def response_body=(body)
      @_response.body = body
    end
    
    # :api: private
    def call(env)
      @_request = ActionDispatch::Request.new(env)
      @_response = ActionDispatch::Response.new
      process(@_request.parameters[:action])
    end
    
    # :api: private
    def to_rack
      response.to_a
    end
  end
end
