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
      def initialize(klass, *args)
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

      reverse.inject(app) do |a, middleware|
        middleware.valid?(action) ?
          middleware.build(a) : a
      end
    end
  end

  # Provides a way to get a valid Rack application from a controller.
  #
  # In AbstractController, dispatching is triggered directly by calling #process on a new controller.
  # <tt>ActionController::Metal</tt> provides an <tt>action</tt> method that returns a valid Rack application for a
  # given action. Other rack builders, such as Rack::Builder, Rack::URLMap, and the \Rails router,
  # can dispatch directly to actions returned by controllers in your application.
  class Metal < AbstractController::Base
    abstract!

    attr_internal :env

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

    def initialize(*)
      @_headers = {"Content-Type" => "text/html"}
      @_status = 200
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

    def self.inherited(base)
      base.middleware_stack = self.middleware_stack.dup
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
