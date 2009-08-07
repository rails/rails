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

    # Returns the full controller name, underscored, without the ending Controller.
    # For instance, MyApp::MyPostsController would return "my_app/my_posts" for
    # controller_name.
    #
    # ==== Returns
    # String
    def self.controller_path
      @controller_path ||= name && name.sub(/Controller$/, '').underscore
    end

    # Delegates to the class' #controller_path
    def controller_path
      self.class.controller_path
    end

    # The details below can be overridden to support a specific
    # Request and Response object. The default ActionController::Base
    # implementation includes RackConvenience, which makes a request
    # and response object available. You might wish to control the
    # environment and response manually for performance reasons.

    attr_internal :status, :headers, :content_type

    def initialize(*)
      @_headers = {}
      super
    end

    # Basic implementations for content_type=, location=, and headers are
    # provided to reduce the dependency on the RackConvenience module
    # in Renderer and Redirector.

    def content_type=(type)
      headers["Content-Type"] = type.to_s
    end

    def location=(url)
      headers["Location"] = url
    end

    # :api: private
    def call(name, env)
      @_env = env
      process(name)
      to_a
    end

    # :api: private
    def to_a
      [status, headers, response_body]
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
    def self.action(name)
      @actions ||= {}
      @actions[name.to_s] ||= proc do |env|
        new.call(name, env)
      end
    end
  end
end
