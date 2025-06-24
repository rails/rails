# frozen_string_literal: true

# :markup: markdown

require "active_support/core_ext/array/extract_options"
require "action_dispatch/middleware/stack"

module ActionController
  # # Action Controller MiddlewareStack
  #
  # Extend ActionDispatch middleware stack to make it aware of options allowing
  # the following syntax in controllers:
  #
  #     class PostsController < ApplicationController
  #       use AuthenticationMiddleware, except: [:index, :show]
  #     end
  #
  class MiddlewareStack < ActionDispatch::MiddlewareStack # :nodoc:
    class Middleware < ActionDispatch::MiddlewareStack::Middleware # :nodoc:
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

  # # Action Controller Metal
  #
  # `ActionController::Metal` is the simplest possible controller, providing a
  # valid Rack interface without the additional niceties provided by
  # ActionController::Base.
  #
  # A sample metal controller might look like this:
  #
  #     class HelloController < ActionController::Metal
  #       def index
  #         self.response_body = "Hello World!"
  #       end
  #     end
  #
  # And then to route requests to your metal controller, you would add something
  # like this to `config/routes.rb`:
  #
  #     get 'hello', to: HelloController.action(:index)
  #
  # The ::action method returns a valid Rack application for the Rails router to
  # dispatch to.
  #
  # ## Rendering Helpers
  #
  # By default, `ActionController::Metal` provides no utilities for rendering
  # views, partials, or other responses aside from some low-level setters such
  # as #response_body=, #content_type=, and #status=. To add the render helpers
  # you're used to having in a normal controller, you can do the following:
  #
  #     class HelloController < ActionController::Metal
  #       include AbstractController::Rendering
  #       include ActionView::Layouts
  #       append_view_path "#{Rails.root}/app/views"
  #
  #       def index
  #         render "hello/index"
  #       end
  #     end
  #
  # ## Redirection Helpers
  #
  # To add redirection helpers to your metal controller, do the following:
  #
  #     class HelloController < ActionController::Metal
  #       include ActionController::Redirecting
  #       include Rails.application.routes.url_helpers
  #
  #       def index
  #         redirect_to root_url
  #       end
  #     end
  #
  # ## Other Helpers
  #
  # You can refer to the modules included in ActionController::Base to see other
  # features you can bring into your metal controller.
  class Metal < AbstractController::Base
    abstract!

    # Returns the last part of the controller's name, underscored, without the
    # ending `Controller`. For instance, `PostsController` returns `posts`.
    # Namespaces are left out, so `Admin::PostsController` returns `posts` as well.
    #
    # #### Returns
    # *   `string`
    def self.controller_name
      @controller_name ||= (name.demodulize.delete_suffix("Controller").underscore unless anonymous?)
    end

    def self.make_response!(request)
      ActionDispatch::Response.new.tap do |res|
        res.request = request
      end
    end

    def self.action_encoding_template(action) # :nodoc:
      false
    end

    class << self
      private
        def inherited(subclass)
          super
          subclass.middleware_stack = middleware_stack.dup
          subclass.class_eval do
            @controller_name = nil
          end
        end
    end

    # Delegates to the class's ::controller_name.
    def controller_name
      self.class.controller_name
    end

    ##
    # :attr_reader: request
    #
    # The ActionDispatch::Request instance for the current request.
    attr_internal :request

    ##
    # :attr_reader: response
    #
    # The ActionDispatch::Response instance for the current response.
    attr_internal_reader :response

    ##
    # The ActionDispatch::Request::Session instance for the current request.
    # See further details in the
    # [Active Controller Session guide](https://guides.rubyonrails.org/action_controller_overview.html#session).
    delegate :session, to: "@_request"

    ##
    # Delegates to ActionDispatch::Response#headers.
    delegate :headers, to: "@_response"

    ##
    # Delegates to ActionDispatch::Response#status=
    delegate :status=, to: "@_response"

    ##
    # Delegates to ActionDispatch::Response#location=
    delegate :location=, to: "@_response"

    ##
    # Delegates to ActionDispatch::Response#content_type=
    delegate :content_type=, to: "@_response"

    ##
    # Delegates to ActionDispatch::Response#status
    delegate :status, to: "@_response"

    ##
    # Delegates to ActionDispatch::Response#location
    delegate :location, to: "@_response"

    ##
    # Delegates to ActionDispatch::Response#content_type
    delegate :content_type, to: "@_response"

    ##
    # Delegates to ActionDispatch::Response#media_type
    delegate :media_type, to: "@_response"

    def initialize
      @_request = nil
      @_response = nil
      @_response_body = nil
      @_routes = nil
      @_params = nil
      super
    end

    def params
      @_params ||= request.parameters
    end

    def params=(val)
      @_params = val
    end

    alias :response_code :status # :nodoc:

    # Basic `url_for` that can be overridden for more robust functionality.
    def url_for(string)
      string
    end

    def response_body=(body)
      if body
        body = [body] if body.is_a?(String)
        response.body = body
        super
      else
        response.reset_body!
      end
    end

    # Tests if render or redirect has already happened.
    def performed?
      response_body || response.committed?
    end

    def dispatch(name, request, response) # :nodoc:
      set_request!(request)
      set_response!(response)
      process(name)
      request.commit_flash
      to_a
    end

    def set_response!(response) # :nodoc:
      if @_response
        _, _, body = @_response
        body.close if body.respond_to?(:close)
      end

      @_response = response
    end

    # Assign the response and mark it as committed. No further processing will
    # occur.
    def response=(response)
      set_response!(response)

      # Force `performed?` to return true:
      @_response_body = true
    end

    def set_request!(request) # :nodoc:
      @_request = request
      @_request.controller_instance = self
    end

    def to_a # :nodoc:
      response.to_a
    end

    def reset_session
      @_request.reset_session
    end

    class_attribute :middleware_stack, default: ActionController::MiddlewareStack.new

    class << self
      # Pushes the given Rack middleware and its arguments to the bottom of the
      # middleware stack.
      def use(...)
        middleware_stack.use(...)
      end
    end

    # The middleware stack used by this controller.
    #
    # By default uses a variation of ActionDispatch::MiddlewareStack which allows
    # for the following syntax:
    #
    #     class PostsController < ApplicationController
    #       use AuthenticationMiddleware, except: [:index, :show]
    #     end
    #
    # Read more about [Rails middleware stack]
    # (https://guides.rubyonrails.org/rails_on_rack.html#action-dispatcher-middleware-stack)
    # in the guides.
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

    # Direct dispatch to the controller. Instantiates the controller, then executes
    # the action named `name`.
    def self.dispatch(name, req, res)
      if middleware_stack.any?
        middleware_stack.build(name) { |env| new.dispatch(name, req, res) }.call req.env
      else
        new.dispatch(name, req, res)
      end
    end
  end
end
