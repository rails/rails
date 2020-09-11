# frozen_string_literal: true

module ActionController
  # ActionController::Renderer allows you to render arbitrary templates
  # without requirement of being in controller actions.
  #
  # You get a concrete renderer class by invoking ActionController::Base#renderer.
  # For example:
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
  # For example:
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
      self.class.new controller, @env, self.defaults.merge(defaults)
    end

    # Accepts a custom Rack environment to render templates in.
    # It will be merged with the default Rack environment defined by
    # +ActionController::Renderer::DEFAULTS+.
    def initialize(controller, env, defaults)
      @controller = controller
      @defaults = defaults
      @env = normalize_keys defaults, env
    end

    # Render templates with any options from ActionController::Base#render_to_string.
    #
    # The primary options are:
    # * <tt>:partial</tt> - See <tt>ActionView::PartialRenderer</tt> for details.
    # * <tt>:file</tt> - Renders an explicit template file. Add <tt>:locals</tt> to pass in, if so desired.
    #   It shouldn’t be used directly with unsanitized user input due to lack of validation.
    # * <tt>:inline</tt> - Renders an ERB template string.
    # * <tt>:plain</tt> - Renders provided text and sets the content type as <tt>text/plain</tt>.
    # * <tt>:html</tt> - Renders the provided HTML safe string, otherwise
    #   performs HTML escape on the string first. Sets the content type as <tt>text/html</tt>.
    # * <tt>:json</tt> - Renders the provided hash or object in JSON. You don't
    #   need to call <tt>.to_json</tt> on the object you want to render.
    # * <tt>:body</tt> - Renders provided text and sets content type of <tt>text/plain</tt>.
    #
    # If no <tt>options</tt> hash is passed or if <tt>:update</tt> is specified, then:
    #
    # If an object responding to `render_in` is passed, `render_in` is called on the object,
    # passing in the current view context.
    #
    # Otherwise, a partial is rendered using the second parameter as the locals hash.
    def render(*args)
      raise "missing controller" unless controller

      request = ActionDispatch::Request.new @env
      request.routes = controller._routes

      instance = controller.new
      instance.set_request! request
      instance.set_response! controller.make_response!(request)
      instance.render_to_string(*args)
    end
    alias_method :render_to_string, :render # :nodoc:

    private
      def normalize_keys(defaults, env)
        new_env = {}
        env.each_pair { |k, v| new_env[rack_key_for(k)] = rack_value_for(k, v) }

        defaults.each_pair do |k, v|
          key = rack_key_for(k)
          new_env[key] = rack_value_for(k, v) unless new_env.key?(key)
        end

        new_env["rack.url_scheme"] = new_env["HTTPS"] == "on" ? "https" : "http"
        new_env
      end

      RACK_KEY_TRANSLATION = {
        http_host:   "HTTP_HOST",
        https:       "HTTPS",
        method:      "REQUEST_METHOD",
        script_name: "SCRIPT_NAME",
        input:       "rack.input"
      }

      def rack_key_for(key)
        RACK_KEY_TRANSLATION[key] || key.to_s
      end

      def rack_value_for(key, value)
        case key
        when :https
          value ? "on" : "off"
        when :method
          -value.upcase
        else
          value
        end
      end
  end
end
