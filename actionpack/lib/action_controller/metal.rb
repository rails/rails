# frozen_string_literal: true

require "active_support/core_ext/array/extract_options"
require "action_dispatch/middleware/stack"
require "action_dispatch/http/request"
require "action_dispatch/http/response"

module ActionController
  # Extend ActionDispatch middleware stack to make it aware of options
  # allowing the following syntax in controllers:
  #
  #   class PostsController < ApplicationController
  #     use AuthenticationMiddleware, except: [:index, :show]
  #   end
  #
  class MiddlewareStack < ActionDispatch::MiddlewareStack #:nodoc:
    class Middleware < ActionDispatch::MiddlewareStack::Middleware #:nodoc:
      def initialize(klass, args, actions, strategy, block)
        @actions = actions
        @strategy = strategy
        super(klass, args, block)
      end

      def valid?(action)
        @strategy.call @actions, action
      end
    end

    def build(action, app = nil, &block)
      action = action.to_s

      middlewares.reverse.inject(app || block) do |a, middleware|
        middleware.valid?(action) ? middleware.build(a) : a
      end
    end

    private
      INCLUDE = ->(list, action) { list.include? action }
      EXCLUDE = ->(list, action) { !list.include? action }
      NULL    = ->(list, action) { true }

      def build_middleware(klass, args, block)
        options = args.extract_options!
        only   = Array(options.delete(:only)).map(&:to_s)
        except = Array(options.delete(:except)).map(&:to_s)
        args << options unless options.empty?

        strategy = NULL
        list     = nil

        if only.any?
          strategy = INCLUDE
          list     = only
        elsif except.any?
          strategy = EXCLUDE
          list     = except
        end

        Middleware.new(klass, args, list, strategy, block)
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
  #   get 'hello', to: HelloController.action(:index)
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
  #     include AbstractController::Rendering
  #     include ActionView::Layouts
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

    # Returns the last part of the controller's name, underscored, without the ending
    # <tt>Controller</tt>. For instance, PostsController returns <tt>posts</tt>.
    # Namespaces are left out, so Admin::PostsController returns <tt>posts</tt> as well.
    #
    # ==== Returns
    # * <tt>string</tt>
    def self.controller_name
      @controller_name ||= (name.demodulize.delete_suffix("Controller").underscore unless anonymous?)
    end

    def self.make_response!(request)
      ActionDispatch::Response.new.tap do |res|
        res.request = request
      end
    end

    def self.binary_params_for?(action) # :nodoc:
      false
    end

    # Delegates to the class' <tt>controller_name</tt>.
    def controller_name
      self.class.controller_name
    end

    attr_internal :response, :request
    delegate :session, to: "@_request"
    delegate :headers, :status=, :location=, :content_type=,
             :status, :location, :content_type, :media_type, to: "@_response"

    def initialize
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

    alias :response_code :status # :nodoc:

    # Basic url_for that can be overridden for more robust functionality.
    def url_for(string)
      string
    end

    def response_body=(body)
      body = [body] unless body.nil? || body.respond_to?(:each)
      response.reset_body!
      return unless body
      response.body = body
      super
    end

    # Tests if render or redirect has already happened.
    def performed?
      response_body || response.committed?
    end

    def dispatch(name, request, response) #:nodoc:
      set_request!(request)
      set_response!(response)
      process(name)
      request.commit_flash
      to_a
    end

    def set_response!(response) # :nodoc:
      @_response = response
    end

    def set_request!(request) #:nodoc:
      @_request = request
      @_request.controller_instance = self
    end

    def to_a #:nodoc:
      response.to_a
    end

    def reset_session
      @_request.reset_session
    end

    class_attribute :middleware_stack, default: ActionController::MiddlewareStack.new

    def self.inherited(base) # :nodoc:
      base.middleware_stack = middleware_stack.dup
      super
    end

    class << self
      # Pushes the given Rack middleware and its arguments to the bottom of the
      # middleware stack.
      def use(*args, &block)
        middleware_stack.use(*args, &block)
      end
      ruby2_keywords(:use) if respond_to?(:ruby2_keywords, true)
    end

    # Alias for +middleware_stack+.
    def self.middleware
      middleware_stack
    end

    # Returns a Rack endpoint for the given action name.
    def self.action(name)
      app = lambda { |env|
        req = ActionDispatch::Request.new(env)
        res = make_response! req
        new.dispatch(name, req, res)
      }

      if middleware_stack.any?
        middleware_stack.build(name, app)
      else
        app
      end
    end

    # Direct dispatch to the controller. Instantiates the controller, then
    # executes the action named +name+.
    def self.dispatch(name, req, res)
      if middleware_stack.any?
        middleware_stack.build(name) { |env| new.dispatch(name, req, res) }.call req.env
      else
        new.dispatch(name, req, res)
      end
    end
  end
end
