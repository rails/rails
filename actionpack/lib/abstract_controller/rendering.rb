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
  # TODO Add some deprecation warnings to remove I18n.locale from controllers
  class I18nProxy < ::I18n::Config #:nodoc:
    attr_reader :i18n_config, :lookup_context

    def initialize(i18n_config, lookup_context)
      @i18n_config, @lookup_context = i18n_config, lookup_context
    end

    def locale
      @i18n_config.locale
    end

    def locale=(value)
      @lookup_context.locale = value
    end
  end

  module Rendering
    extend ActiveSupport::Concern

    include AbstractController::ViewPaths

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
          controller = self
          Class.new(ActionView::Base) do
            if controller.respond_to?(:_routes)
              include controller._routes.url_helpers
            end

            if controller.respond_to?(:_helpers)
              include controller._helpers

              # TODO: Fix RJS to not require this
              self.helpers = controller._helpers
            end
          end
        end
      end
    end

    attr_writer :view_context_class

    def view_context_class
      @view_context_class || self.class.view_context_class
    end

    def initialize(*)
      @view_context_class = nil
      super
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
      view_context_class.new(lookup_context, view_assigns, self)
    end

    # Normalize arguments, options and then delegates render_to_body and
    # sticks the result in self.response_body.
    def render(*args, &block)
      self.response_body = render_to_string(*args, &block)
    end

    # Raw rendering of a template to a string. Just convert the results of
    # render_to_body into a String.
    # :api: plugin
    def render_to_string(*args, &block)
      options = _normalize_args(*args, &block)
      _normalize_options(options)
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
      view_context.render(options)
    end

    # The prefix used in render "foo" shortcuts.
    def _prefix
      controller_path
    end

  private

    # This method should return a hash with assigns.
    # You can overwrite this configuration per controller.
    # :api: public
    def view_assigns
      hash = {}
      variables  = instance_variable_names
      variables -= protected_instance_variables if respond_to?(:protected_instance_variables)
      variables.each { |name| hash[name.to_s[1..-1]] = instance_variable_get(name) }
      hash
    end

    # Normalize options by converting render "foo" to render :action => "foo" and
    # render "foo/bar" to render :file => "foo/bar".
    def _normalize_args(action=nil, options={})
      case action
      when NilClass
      when Hash
        options, action = action, nil
      when String, Symbol
        action = action.to_s
        key = action.include?(?/) ? :file : :action
        options[key] = action
      else
        options.merge!(:partial => action)
      end

      options
    end

    def _normalize_options(options)
      if options[:partial] == true
        options[:partial] = action_name
      end

      if (options.keys & [:partial, :file, :template]).empty?
        options[:prefix] ||= _prefix
      end

      options[:template] ||= (options[:action] || action_name).to_s
      options
    end

    def _process_options(options)
    end
  end
end
