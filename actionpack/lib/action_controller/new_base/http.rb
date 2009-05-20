require 'action_controller/abstract'
require 'active_support/core_ext/module/delegation'

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
    def self.action_names() action_methods end
    
    # :api: private
    def action_names() action_methods end
    
    # :api: plugin
    def self.call(env)
      controller = new
      controller.call(env).to_rack
    end
    
    delegate :headers, :to => "@_response"

    def params
      @_params ||= @_request.parameters
    end
    
    # :api: private
    def call(name, env)
      @_request = ActionDispatch::Request.new(env)
      @_response = ActionDispatch::Response.new
      @_response.request = request
      process(name)
      to_rack
    end
    
    def self.action(name)
      @actions ||= {}
      @actions[name.to_s] ||= proc do |env|
        new.call(name, env)
      end
    end
    
    # :api: private
    def to_rack
      @_response.prepare!
      @_response.to_a
    end
  end
end
