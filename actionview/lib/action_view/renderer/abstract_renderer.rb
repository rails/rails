# frozen_string_literal: true

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
    delegate :template_exists?, :any_templates?, :formats, to: :@lookup_context

    def initialize(lookup_context)
      @lookup_context = lookup_context
    end

    def render
      raise NotImplementedError
    end

    class RenderedCollection # :nodoc:
      def self.empty(format)
        EmptyCollection.new format
      end

      attr_reader :rendered_templates

      def initialize(rendered_templates, spacer)
        @rendered_templates = rendered_templates
        @spacer = spacer
      end

      def body
        @rendered_templates.map(&:body).join(@spacer.body).html_safe
      end

      def format
        rendered_templates.first.format
      end

      class EmptyCollection
        attr_reader :format

        def initialize(format)
          @format = format
        end

        def body; nil; end
      end
    end

    class RenderedTemplate # :nodoc:
      attr_reader :body, :layout, :template

      def initialize(body, layout, template)
        @body = body
        @layout = layout
        @template = template
      end

      def format
        template.format
      end

      EMPTY_SPACER = Struct.new(:body).new
    end

    private
      def extract_details(options) # :doc:
        @lookup_context.registered_details.each_with_object({}) do |key, details|
          value = options[key]

          details[key] = Array(value) if value
        end
      end

      def instrument(name, **options) # :doc:
        ActiveSupport::Notifications.instrument("render_#{name}.action_view", options) do |payload|
          yield payload
        end
      end

      def prepend_formats(formats) # :doc:
        formats = Array(formats)
        return if formats.empty? || @lookup_context.html_fallback_for_js

        @lookup_context.formats = formats | @lookup_context.formats
      end

      def build_rendered_template(content, template, layout = nil)
        RenderedTemplate.new content, layout, template
      end

      def build_rendered_collection(templates, spacer)
        RenderedCollection.new templates, spacer
      end
  end
end
