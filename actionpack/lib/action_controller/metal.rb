require 'active_support/core_ext/class/attribute'

module ActionController
  # ActionController::Metal provides a way to get a valid Rack application from a controller.
  #
  # In AbstractController, dispatching is triggered directly by calling #process on a new controller.
  # ActionController::Metal provides an #action method that returns a valid Rack application for a
  # given action. Other rack builders, such as Rack::Builder, Rack::URLMap, and the Rails router,
  # can dispatch directly to the action returned by FooController.action(:index).
  class Metal < AbstractController::Base
    abstract!

    # :api: public
    attr_internal :params, :env

    # Returns the last part of the controller's name, underscored, without the ending
    # "Controller". For instance, MyApp::MyPostsController would return "my_posts" for
    # controller_name
    #
    # ==== Returns
    # String
    def self.controller_name
      @controller_name ||= controller_path.split("/").last
    end

    # Delegates to the class' #controller_name
    def controller_name
      self.class.controller_name
    end

    # The details below can be overridden to support a specific
    # Request and Response object. The default ActionController::Base
    # implementation includes RackDelegation, which makes a request
    # and response object available. You might wish to control the
    # environment and response manually for performance reasons.

    attr_internal :headers, :response, :request
    delegate :session, :to => "@_request"

    def initialize(*)
      @_headers = {"Content-Type" => "text/html"}
      @_status = 200
      super
    end

    # Basic implementations for content_type=, location=, and headers are
    # provided to reduce the dependency on the RackDelegation module
    # in Renderer and Redirector.

    def content_type=(type)
      headers["Content-Type"] = type.to_s
    end

    def content_type
      headers["Content-Type"]
    end

    def location
      headers["Location"]
    end

    def location=(url)
      headers["Location"] = url
    end

    def status
      @_status
    end

    def status=(status)
      @_status = Rack::Utils.status_code(status)
    end

    def response_body=(val)
      body = val.respond_to?(:each) ? val : [val]
      super body
    end

    # :api: private
    def dispatch(name, request)
      @_request = request
      @_env = request.env
      @_env['action_controller.instance'] = self
      process(name)
      to_a
    end

    # :api: private
    def to_a
      response ? response.to_a : [status, headers, response_body]
    end

    class_attribute :middleware_stack
    self.middleware_stack = ActionDispatch::MiddlewareStack.new

    def self.inherited(base)
      self.middleware_stack = base.middleware_stack.dup
      super
    end

    def self.use(*args)
      middleware_stack.use(*args)
    end

    def self.middleware
      middleware_stack
    end

    def self.call(env)
      action(env['action_dispatch.request.path_parameters'][:action]).call(env)
    end

    # Return a rack endpoint for the given action. Memoize the endpoint, so
    # multiple calls into MyController.action will return the same object
    # for the same action.
    #
    # ==== Parameters
    # action<#to_s>:: An action name
    #
    # ==== Returns
    # Proc:: A rack application
    def self.action(name, klass = ActionDispatch::Request)
      middleware_stack.build do |env|
        new.dispatch(name, klass.new(env))
      end
    end
  end
end
