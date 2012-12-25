require "abstract_controller/base"
require "action_view"

module AbstractController
  class DoubleRenderError < Error
    DEFAULT_MESSAGE = "Render and/or redirect were called multiple times in this action. Please note that you may only call render OR redirect, and at most once per action. Also note that neither redirect nor render terminate execution of the action, so if you want to exit an action after redirecting, you need to do something like \"redirect_to(...) and return\"."

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  # This is a class to fix I18n global state. Whenever you provide I18n.locale during a request,
  # it will trigger the lookup_context and consequently expire the cache.
  class I18nProxy < ::I18n::Config #:nodoc:
    attr_reader :original_config, :lookup_context

    def initialize(original_config, lookup_context)
      original_config = original_config.original_config if original_config.respond_to?(:original_config)
      @original_config, @lookup_context = original_config, lookup_context
    end

    def locale
      @original_config.locale
    end

    def locale=(value)
      @lookup_context.locale = value
    end
  end

  module Rendering
    extend ActiveSupport::Concern
    include AbstractController::ViewPaths

    included do
      class_attribute :protected_instance_variables
      self.protected_instance_variables = []
    end

    # Overwrite process to setup I18n proxy.
    def process(*) #:nodoc:
      old_config, I18n.config = I18n.config, I18nProxy.new(I18n.config, lookup_context)
      super
    ensure
      I18n.config = old_config
    end

    module ClassMethods
      def view_context_class
        @view_context_class ||= begin
          routes = respond_to?(:_routes) && _routes
          helpers = respond_to?(:_helpers) && _helpers

          Class.new(ActionView::Base) do
            if routes
              include routes.url_helpers
              include routes.mounted_helpers
            end

            if helpers
              include helpers
            end
          end
        end
      end
    end

    attr_internal_writer :view_context_class

    def view_context_class
      @_view_context_class ||= self.class.view_context_class
    end

    # An instance of a view class. The default view class is ActionView::Base
    #
    # The view class must have the following methods:
    # View.new[lookup_context, assigns, controller]
    #   Create a new ActionView instance for a controller
    # View#render[options]
    #   Returns String with the rendered template
    #
    # Override this method in a module to change the default behavior.
    def view_context
      view_context_class.new(view_renderer, view_assigns, self)
    end

    # Returns an object that is able to render templates.
    def view_renderer
      @_view_renderer ||= ActionView::Renderer.new(lookup_context)
    end

    # Normalize arguments, options and then delegates render_to_body and
    # sticks the result in self.response_body.
    def render(*args, &block)
      options = _normalize_render(*args, &block)
      self.response_body = render_to_body(options)
    end

    # Raw rendering of a template to a string. Just convert the results of
    # render_response into a String.
    # :api: plugin
    def render_to_string(*args, &block)
      options = _normalize_render(*args, &block)
      render_to_body(options)
    end

    # Raw rendering of a template to a Rack-compatible body.
    # :api: plugin
    def render_to_body(options = {})
      _process_options(options)
      _render_template(options)
    end

    # Find and renders a template based on the options given.
    # :api: private
    def _render_template(options) #:nodoc:
      lookup_context.rendered_format = nil if options[:formats]
      view_renderer.render(view_context, options)
    end

    DEFAULT_PROTECTED_INSTANCE_VARIABLES = [
      :@_action_name, :@_response_body, :@_formats, :@_prefixes, :@_config,
      :@_view_context_class, :@_view_renderer, :@_lookup_context
    ]

    # This method should return a hash with assigns.
    # You can overwrite this configuration per controller.
    # :api: public
    def view_assigns
      hash = {}
      variables  = instance_variables
      variables -= protected_instance_variables
      variables -= DEFAULT_PROTECTED_INSTANCE_VARIABLES
      variables.each { |name| hash[name[1..-1]] = instance_variable_get(name) }
      hash
    end

    private

    # Normalize args and options.
    # :api: private
    def _normalize_render(*args, &block)
      options = _normalize_args(*args, &block)
      _normalize_options(options)
      options
    end

    # Normalize args by converting render "foo" to render :action => "foo" and
    # render "foo/bar" to render :file => "foo/bar".
    # :api: plugin
    def _normalize_args(action=nil, options={})
      case action
      when NilClass
      when Hash
        options = action
      when String, Symbol
        action = action.to_s
        key = action.include?(?/) ? :file : :action
        options[key] = action
      else
        options[:partial] = action
      end

      options
    end

    # Normalize options.
    # :api: plugin
    def _normalize_options(options)
      if options[:partial] == true
        options[:partial] = action_name
      end

      if (options.keys & [:partial, :file, :template]).empty?
        options[:prefixes] ||= _prefixes
      end

      options[:template] ||= (options[:action] || action_name).to_s
      options
    end

    # Process extra options.
    # :api: plugin
    def _process_options(options)
    end
  end
end
