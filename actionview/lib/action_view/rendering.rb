# frozen_string_literal: true

require "action_view/view_paths"

module ActionView
  # This is a class to fix I18n global state. Whenever you provide I18n.locale during a request,
  # it will trigger the lookup_context and consequently expire the cache.
  class I18nProxy < ::I18n::Config # :nodoc:
    attr_reader :original_config, :lookup_context

    def initialize(original_config, lookup_context)
      original_config = original_config.original_config if original_config.respond_to?(:original_config)
      @original_config = original_config
      @lookup_context = lookup_context
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
    include ActionView::ViewPaths

    attr_internal_reader :rendered_format

    def initialize
      @_rendered_format = nil
      super
    end

    # Override process to set up I18n proxy.
    def process(...) # :nodoc:
      old_config, I18n.config = I18n.config, I18nProxy.new(I18n.config, lookup_context)
      super
    ensure
      I18n.config = old_config
    end

    module ClassMethods
      def _routes
      end

      def _helpers
      end

      def inherit_view_context_class?
        superclass.respond_to?(:view_context_class) &&
          supports_path? == superclass.supports_path? &&
          _routes.equal?(superclass._routes) &&
          _helpers.equal?(superclass._helpers)
      end

      def build_view_context_class(klass, supports_path, routes, helpers)
        if inherit_view_context_class?
          return superclass.view_context_class
        end

        Class.new(klass) do
          if routes
            include routes.url_helpers(supports_path)
            include routes.mounted_helpers
          end

          if helpers
            include helpers
          end
        end
      end

      def eager_load!
        super
        view_context_class
        nil
      end

      def view_context_class
        klass = ActionView::LookupContext::DetailsKey.view_context_class

        @view_context_class ||= build_view_context_class(klass, supports_path?, _routes, _helpers)

        if klass.changed?(@view_context_class)
          @view_context_class = build_view_context_class(klass, supports_path?, _routes, _helpers)
        end

        @view_context_class
      end
    end

    def view_context_class
      self.class.view_context_class
    end

    # An instance of a view class. The default view class is ActionView::Base.
    #
    # The view class must have the following methods:
    #
    # * <tt>View.new(lookup_context, assigns, controller)</tt> — Create a new
    #   ActionView instance for a controller and we can also pass the arguments.
    #
    # * <tt>View#render(option)</tt> — Returns String with the rendered template.
    #
    # Override this method in a module to change the default behavior.
    def view_context
      view_context_class.new(lookup_context, view_assigns, self)
    end

    # Returns an object that is able to render templates.
    def view_renderer # :nodoc:
      # Lifespan: Per controller
      @_view_renderer ||= ActionView::Renderer.new(lookup_context)
    end

    def render_to_body(options = {})
      _process_options(options)
      _process_render_template_options(options)
      _render_template(options)
    end

    private
      # Find and render a template based on the options given.
      def _render_template(options)
        variant = options.delete(:variant)
        assigns = options.delete(:assigns)
        context = view_context

        context.assign assigns if assigns
        lookup_context.variants = variant if variant

        rendered_template = context.in_rendering_context(options) do |renderer|
          renderer.render_to_object(context, options)
        end

        rendered_format = rendered_template.format || lookup_context.formats.first
        @_rendered_format = Template::Types[rendered_format]

        rendered_template.body
      end

      # Assign the rendered format to look up context.
      def _process_format(format)
        super
        lookup_context.formats = [format.to_sym] if format.to_sym
      end

      # Normalize args by converting render "foo" to render action: "foo" and
      # render "foo/bar" to render template: "foo/bar".
      def _normalize_args(action = nil, options = {})
        options = super(action, options)
        case action
        when NilClass
        when Hash
          options = action
        when String, Symbol
          action = action.to_s
          key = action.include?(?/) ? :template : :action
          options[key] = action
        else
          if action.respond_to?(:permitted?) && action.permitted?
            options = action
          elsif action.respond_to?(:render_in)
            options[:renderable] = action
          else
            options[:partial] = action
          end
        end

        options
      end

      # Normalize options.
      def _process_render_template_options(options)
        if options[:partial] == true
          options[:partial] = action_name
        end

        if !options.keys.intersect?([:partial, :file, :template])
          options[:prefixes] ||= _prefixes
        end

        options[:template] ||= (options[:action] || action_name).to_s
      end
  end
end
