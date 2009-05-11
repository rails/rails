module ActionController
  class Http < AbstractController::Base
    abstract!
    
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
    def self.internal_methods
      ActionController::Http.public_instance_methods(true)
    end
    
    # :api: private    
    def self.action_names() action_methods end
    
    # :api: private
    def action_names() action_methods end
    
    # :api: plugin
    def self.call(env)
      controller = new
      controller.call(env).to_rack
    end
    
    # :api: private
    def call(name, env)
      @_request = ActionDispatch::Request.new(env)
      @_response = ActionDispatch::Response.new
      @_response.request = request
      process(name)
      @_response.body = response_body
      @_response.prepare!
      to_rack
    end
    
    def self.action(name)
      @actions ||= {}
      @actions[name] ||= proc do |env| 
        new.call(name, env)
      end
    end
    
    # :api: private
    def to_rack
      @_response.to_a
    end
  end
end
