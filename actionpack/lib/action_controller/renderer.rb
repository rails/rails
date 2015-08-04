require 'active_support/core_ext/hash/keys'

module ActionController
  # ActionController::Renderer allows to render arbitrary templates
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
  # You can use a shortcut on controller to replace previous example with:
  #
  #   ApplicationController.render template: '...'
  #
  # #render method allows you to use any options as when rendering in controller.
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
    class_attribute :controller, :defaults
    # Rack environment to render templates in.
    attr_reader :env

    class << self
      delegate :render, to: :new

      # Create a new renderer class for a specific controller class.
      def for(controller)
        Class.new self do
          self.controller = controller
          self.defaults = {
            http_host: 'example.org',
            https: false,
            method: 'get',
            script_name: '',
            'rack.input' => ''
          }
        end
      end
    end

    # Accepts a custom Rack environment to render templates in.
    # It will be merged with ActionController::Renderer.defaults
    def initialize(env = {})
      @env = normalize_keys(defaults).merge normalize_keys(env)
      @env['action_dispatch.routes'] = controller._routes
    end

    # Render templates with any options from ActionController::Base#render_to_string.
    def render(*args)
      raise 'missing controller' unless controller?

      instance = controller.build_with_env(env)
      instance.render_to_string(*args)
    end

    private
      def normalize_keys(env)
        http_header_format(env).tap do |new_env|
          handle_method_key! new_env
          handle_https_key!  new_env
        end
      end

      def http_header_format(env)
        env.transform_keys do |key|
          key.is_a?(Symbol) ? key.to_s.upcase : key
        end
      end

      def handle_method_key!(env)
        if method = env.delete('METHOD')
          env['REQUEST_METHOD'] = method.upcase
        end
      end

      def handle_https_key!(env)
        if env.has_key? 'HTTPS'
          env['HTTPS'] = env['HTTPS'] ? 'on' : 'off'
        end
      end
  end
end
