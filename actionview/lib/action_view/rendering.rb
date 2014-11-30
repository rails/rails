require "action_view/view_paths"

module ActionView
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
    include ActionView::ViewPaths

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
          supports_path = supports_path?
          routes  = respond_to?(:_routes)  && _routes
          helpers = respond_to?(:_helpers) && _helpers

          Class.new(ActionView::Base) do
            if routes
              include routes.url_helpers(supports_path)
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
    #   Create a new ActionView instance for a controller and we can also pass the arguments.
    # View#render(option)
    #   Returns String with the rendered template
    #
    # Override this method in a module to change the default behavior.
    def view_context
      view_context_class.new(view_renderer, view_assigns, self)
    end

    # Returns an object that is able to render templates.
    # :api: private
    def view_renderer
      @_view_renderer ||= ActionView::Renderer.new(lookup_context)
    end

    def render_to_body(options = {})
      _process_options(options)
      _render_template(options)
    end

    def rendered_format
      Mime[lookup_context.rendered_format]
    end

    private

      # Find and render a template based on the options given.
      # :api: private
      def _render_template(options) #:nodoc:
        variant = options[:variant]

        lookup_context.rendered_format = nil if options[:formats]
        lookup_context.variants = variant if variant

        view_renderer.render(view_context, options)
      end

      # Assign the rendered format to lookup context.
      def _process_format(format, options = {}) #:nodoc:
        super
        lookup_context.formats = [format.to_sym]
        lookup_context.rendered_format = lookup_context.formats.first
      end

      # Normalize args by converting render "foo" to render :action => "foo" and
      # render "foo/bar" to render :template => "foo/bar".
      # :api: private
      def _normalize_args(action=nil, options={})
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
          options[:partial] = action
        end

        options
      end

      # Normalize options.
      # :api: private
      def _normalize_options(options)
        options = super(options)
        if options[:partial] == true
          options[:partial] = action_name
        end

        if (options.keys & [:partial, :file, :template]).empty?
          options[:prefixes] ||= _prefixes
        end

        options[:template] ||= (options[:action] || action_name).to_s
        options
      end
  end
end
