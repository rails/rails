module ActionView
  # This class defines the interface for a renderer. Each class that
  # subclasses +AbstractRenderer+ is used by the base +Renderer+ class to
  # render a specific type of object.
  #
  # The base +Renderer+ class uses its +render+ method to delegate to the
  # renderers. These currently consist of
  #
  #   PartialRenderer - Used for rendering partials
  #   TemplateRenderer - Used for rendering other types of templates
  #   StreamingTemplateRenderer - Used for streaming
  #
  # Whenever the +render+ method is called on the base +Renderer+ class, a new
  # renderer object of the correct type is created, and the +render+ method on
  # that new object is called in turn. This abstracts the setup and rendering
  # into a separate classes for partials and templates.
  class AbstractRenderer #:nodoc:
    delegate :find_template, :template_exists?, :with_fallbacks, :with_layout_format, :formats, :to => :@lookup_context

    def initialize(lookup_context)
      @lookup_context = lookup_context
    end

    def render
      raise NotImplementedError
    end

    protected

    def extract_details(options)
      @lookup_context.registered_details.each_with_object({}) do |key, details|
        value = options[key]

        details[key] = Array(value) if value
      end
    end

    def instrument(name, options={})
      ActiveSupport::Notifications.instrument("render_#{name}.action_view", options){ yield }
    end

    def prepend_formats(formats)
      formats = Array(formats)
      return if formats.empty? || @lookup_context.html_fallback_for_js

      @lookup_context.formats = formats | @lookup_context.formats
    end
  end
end
