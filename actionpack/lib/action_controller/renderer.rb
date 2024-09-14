# frozen_string_literal: true

# :markup: markdown

module ActionController
  # # Action Controller Renderer
  #
  # ActionController::Renderer allows you to render arbitrary templates without
  # being inside a controller action.
  #
  # You can get a renderer instance by calling `renderer` on a controller class:
  #
  #     ApplicationController.renderer
  #     PostsController.renderer
  #
  # and render a template by calling the #render method:
  #
  #     ApplicationController.renderer.render template: "posts/show", assigns: { post: Post.first }
  #     PostsController.renderer.render :show, assigns: { post: Post.first }
  #
  # As a shortcut, you can also call `render` directly on the controller class
  # itself:
  #
  #     ApplicationController.render template: "posts/show", assigns: { post: Post.first }
  #     PostsController.render :show, assigns: { post: Post.first }
  #
  class Renderer
    attr_reader :controller

    DEFAULTS = {
      method: "get",
      input: ""
    }.freeze

    def self.normalize_env(env) # :nodoc:
      new_env = {}

      env.each_pair do |key, value|
        case key
        when :https
          value = value ? "on" : "off"
        when :method
          value = -value.upcase
        end

        key = RACK_KEY_TRANSLATION[key] || key.to_s

        new_env[key] = value
      end

      if new_env["HTTP_HOST"]
        new_env["HTTPS"] ||= "off"
        new_env["SCRIPT_NAME"] ||= ""
      end

      if new_env["HTTPS"]
        new_env["rack.url_scheme"] = new_env["HTTPS"] == "on" ? "https" : "http"
      end

      new_env
    end

    # Creates a new renderer using the given controller class. See ::new.
    def self.for(controller, env = nil, defaults = DEFAULTS)
      new(controller, env, defaults)
    end

    # Creates a new renderer using the same controller, but with a new Rack env.
    #
    #     ApplicationController.renderer.new(method: "post")
    #
    def new(env = nil)
      self.class.new controller, env, @defaults
    end

    # Creates a new renderer using the same controller, but with the given defaults
    # merged on top of the previous defaults.
    def with_defaults(defaults)
      self.class.new controller, @env, @defaults.merge(defaults)
    end

    # Initializes a new Renderer.
    #
    # #### Parameters
    #
    # *   `controller` - The controller class to instantiate for rendering.
    # *   `env` - The Rack env to use for mocking a request when rendering. Entries
    #     can be typical Rack env keys and values, or they can be any of the
    #     following, which will be converted appropriately:
    #     *   `:http_host` - The HTTP host for the incoming request. Converts to
    #         Rack's `HTTP_HOST`.
    #     *   `:https` - Boolean indicating whether the incoming request uses HTTPS.
    #         Converts to Rack's `HTTPS`.
    #     *   `:method` - The HTTP method for the incoming request,
    #         case-insensitive. Converts to Rack's `REQUEST_METHOD`.
    #     *   `:script_name` - The portion of the incoming request's URL path that
    #         corresponds to the application. Converts to Rack's `SCRIPT_NAME`.
    #     *   `:input` - The input stream. Converts to Rack's `rack.input`.
    #
    # *   `defaults` - Default values for the Rack env. Entries are specified in the
    #     same format as `env`. `env` will be merged on top of these values.
    #     `defaults` will be retained when calling #new on a renderer instance.
    #
    #
    # If no `http_host` is specified, the env HTTP host will be derived from the
    # routes' `default_url_options`. In this case, the `https` boolean and the
    # `script_name` will also be derived from `default_url_options` if they were not
    # specified. Additionally, the `https` boolean will fall back to
    # `Rails.application.config.force_ssl` if `default_url_options` does not specify
    # a `protocol`.
    def initialize(controller, env, defaults)
      @controller = controller
      @defaults = defaults
      if env.blank? && @defaults == DEFAULTS
        @env = DEFAULT_ENV
      else
        @env = normalize_env(@defaults)
        @env.merge!(normalize_env(env)) unless env.blank?
      end
    end

    def defaults
      @defaults = @defaults.dup if @defaults.frozen?
      @defaults
    end

    # Renders a template to a string, just like
    # ActionController::Rendering#render_to_string.
    def render(*args)
      request = ActionDispatch::Request.new(env_for_request)
      request.routes = controller._routes

      instance = controller.new
      instance.set_request! request
      instance.set_response! controller.make_response!(request)
      instance.render_to_string(*args)
    end
    alias_method :render_to_string, :render # :nodoc:

    private
      RACK_KEY_TRANSLATION = {
        http_host:   "HTTP_HOST",
        https:       "HTTPS",
        method:      "REQUEST_METHOD",
        script_name: "SCRIPT_NAME",
        input:       "rack.input"
      }

      DEFAULT_ENV = normalize_env(DEFAULTS).freeze # :nodoc:

      delegate :normalize_env, to: :class

      def env_for_request
        if @env.key?("HTTP_HOST") || controller._routes.nil?
          @env.dup
        else
          controller._routes.default_env.merge(@env)
        end
      end
  end
end
