require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object/blank'
require 'action_dispatch/middleware/stack'

module ActionController
  # Extend ActionDispatch middleware stack to make it aware of options
  # allowing the following syntax in controllers:
  #
  #   class PostsController < ApplicationController
  #     use AuthenticationMiddleware, :except => [:index, :show]
  #   end
  #
  class MiddlewareStack < ActionDispatch::MiddlewareStack #:nodoc:
    class Middleware < ActionDispatch::MiddlewareStack::Middleware #:nodoc:
      def initialize(klass, *args, &block)
        options = args.extract_options!
        @only   = Array(options.delete(:only)).map(&:to_s)
        @except = Array(options.delete(:except)).map(&:to_s)
        args << options unless options.empty?
        super
      end

      def valid?(action)
        if @only.present?
          @only.include?(action)
        elsif @except.present?
          !@except.include?(action)
        else
          true
        end
      end
    end

    def build(action, app=nil, &block)
      app  ||= block
      action = action.to_s
      raise "MiddlewareStack#build requires an app" unless app

      middlewares.reverse.inject(app) do |a, middleware|
        middleware.valid?(action) ?
          middleware.build(a) : a
      end
    end
  end

  # <tt>ActionController::Metal</tt> is the simplest possible controller, providing a
  # valid Rack interface without the additional niceties provided by
  # <tt>ActionController::Base</tt>.
  #
  # A sample metal controller might look like this:
  #
  #   class HelloController < ActionController::Metal
  #     def index
  #       self.response_body = "Hello World!"
  #     end
  #   end
  #
  # And then to route requests to your metal controller, you would add
  # something like this to <tt>config/routes.rb</tt>:
  #
  #   match 'hello', :to => HelloController.action(:index)
  #
  # The +action+ method returns a valid Rack application for the \Rails
  # router to dispatch to.
  #
  # == Rendering Helpers
  #
  # <tt>ActionController::Metal</tt> by default provides no utilities for rendering
  # views, partials, or other responses aside from explicitly calling of
  # <tt>response_body=</tt>, <tt>content_type=</tt>, and <tt>status=</tt>. To
  # add the render helpers you're used to having in a normal controller, you
  # can do the following:
  #
  #   class HelloController < ActionController::Metal
  #     include ActionController::Rendering
  #     append_view_path "#{Rails.root}/app/views"
  #
  #     def index
  #       render "hello/index"
  #     end
  #   end
  #
  # == Redirection Helpers
  #
  # To add redirection helpers to your metal controller, do the following:
  #
  #   class HelloController < ActionController::Metal
  #     include ActionController::Redirecting
  #     include Rails.application.routes.url_helpers
  #
  #     def index
  #       redirect_to root_url
  #     end
  #   end
  #
  # == Other Helpers
  #
  # You can refer to the modules included in <tt>ActionController::Base</tt> to see
  # other features you can bring into your metal controller.
  #
  class Metal < AbstractController::Base
    abstract!

    attr_internal_writer :env

    def env
      @_env ||= {}
    end

    # Returns the last part of the controller's name, underscored, without the ending
    # <tt>Controller</tt>. For instance, PostsController returns <tt>posts</tt>.
    # Namespaces are left out, so Admin::PostsController returns <tt>posts</tt> as well.
    #
    # ==== Returns
    # * <tt>string</tt>
    def self.controller_name
      @controller_name ||= self.name.demodulize.sub(/Controller$/, '').underscore
    end

    # Delegates to the class' <tt>controller_name</tt>
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

    def initialize
      @_headers = {"Content-Type" => "text/html"}
      @_status = 200
      @_request = nil
      @_response = nil
      @_routes = nil
      super
    end

    def params
      @_params ||= request.parameters
    end

    def params=(val)
      @_params = val
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

    # basic url_for that can be overridden for more robust functionality
    def url_for(string)
      string
    end

    def status
      @_status
    end

    def status=(status)
      @_status = Rack::Utils.status_code(status)
    end

    def response_body=(val)
      body = if val.is_a?(String)
        [val]
      elsif val.nil? || val.respond_to?(:each)
        val
      else
        [val]
      end
      super body
    end

    def performed?
      response_body
    end

    def dispatch(name, request) #:nodoc:
      @_request = request
      @_env = request.env
      @_env['action_controller.instance'] = self
      process(name)
      to_a
    end

    def to_a #:nodoc:
      response ? response.to_a : [status, headers, response_body]
    end

    class_attribute :middleware_stack
    self.middleware_stack = ActionController::MiddlewareStack.new

    def self.inherited(base) #nodoc:
      base.middleware_stack = self.middleware_stack.dup
      super
    end

    # Adds given middleware class and its args to bottom of middleware_stack
    def self.use(*args, &block)
      middleware_stack.use(*args, &block)
    end

    # Alias for middleware_stack
    def self.middleware
      middleware_stack
    end

    # Makes the controller a rack endpoint that points to the action in
    # the given env's action_dispatch.request.path_parameters key.
    def self.call(env)
      action(env['action_dispatch.request.path_parameters'][:action]).call(env)
    end

    # Return a rack endpoint for the given action. Memoize the endpoint, so
    # multiple calls into MyController.action will return the same object
    # for the same action.
    #
    # ==== Parameters
    # * <tt>action</tt> - An action name
    #
    # ==== Returns
    # * <tt>proc</tt> - A rack application
    def self.action(name, klass = ActionDispatch::Request)
      middleware_stack.build(name.to_s) do |env|
        new.dispatch(name, klass.new(env))
      end
    end
  end
end
