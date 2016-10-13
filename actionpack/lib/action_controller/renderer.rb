require "active_support/core_ext/hash/keys"

module ActionController
  # ActionController::Renderer allows you to render arbitrary templates
  # without requirement of being in controller actions.
  #
  # You get a concrete renderer class by invoking ActionController::Base#renderer.
  # For example,
  #
  #   ApplicationController.renderer
  #
  # It allows you to call method #render directly.
  #
  #   ApplicationController.renderer.render template: '...'
  #
  # You can use this shortcut in a controller, instead of the previous example:
  #
  #   ApplicationController.render template: '...'
  #
  # #render allows you to use the same options that you can use when rendering in a controller.
  # For example,
  #
  #   FooController.render :action, locals: { ... }, assigns: { ... }
  #
  # The template will be rendered in a Rack environment which is accessible through
  # ActionController::Renderer#env. You can set it up in two ways:
  #
  # *  by changing renderer defaults, like
  #
  #       ApplicationController.renderer.defaults # => hash with default Rack environment
  #
  # *  by initializing an instance of renderer by passing it a custom environment.
  #
  #       ApplicationController.renderer.new(method: 'post', https: true)
  #
  class Renderer
    attr_reader :defaults, :controller

    DEFAULTS = {
      http_host: "example.org",
      https: false,
      method: "get",
      script_name: "",
      input: ""
    }.freeze

    # Create a new renderer instance for a specific controller class.
    def self.for(controller, env = {}, defaults = DEFAULTS.dup)
      new(controller, env, defaults)
    end

    # Create a new renderer for the same controller but with a new env.
    def new(env = {})
      self.class.new controller, env, defaults
    end

    # Create a new renderer for the same controller but with new defaults.
    def with_defaults(defaults)
      self.class.new controller, env, self.defaults.merge(defaults)
    end

    # Accepts a custom Rack environment to render templates in.
    # It will be merged with ActionController::Renderer.defaults
    def initialize(controller, env, defaults)
      @controller = controller
      @defaults = defaults
      @env = normalize_keys defaults.merge(env)
    end

    # Render templates with any options from ActionController::Base#render_to_string.
    def render(*args)
      raise "missing controller" unless controller

      request = ActionDispatch::Request.new @env
      request.routes = controller._routes

      instance = controller.new
      instance.set_request! request
      instance.set_response! controller.make_response!(request)
      instance.render_to_string(*args)
    end

    private
      def normalize_keys(env)
        new_env = {}
        env.each_pair { |k,v| new_env[rack_key_for(k)] = rack_value_for(k, v) }
        new_env
      end

      RACK_KEY_TRANSLATION = {
        http_host:   "HTTP_HOST",
        https:       "HTTPS",
        method:      "REQUEST_METHOD",
        script_name: "SCRIPT_NAME",
        input:       "rack.input"
      }

      IDENTITY = ->(_) { _ }

      RACK_VALUE_TRANSLATION = {
        https: ->(v) { v ? "on" : "off" },
        method: ->(v) { v.upcase },
      }

      def rack_key_for(key)
        RACK_KEY_TRANSLATION.fetch(key, key.to_s)
      end

      def rack_value_for(key, value)
        RACK_VALUE_TRANSLATION.fetch(key, IDENTITY).call value
      end
  end
end
