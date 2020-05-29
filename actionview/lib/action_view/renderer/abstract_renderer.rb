# frozen_string_literal: true

require "concurrent/map"

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
  # that new object is called in turn. This abstracts the set up and rendering
  # into a separate classes for partials and templates.
  class AbstractRenderer #:nodoc:
    delegate :template_exists?, :any_templates?, :formats, to: :@lookup_context

    def initialize(lookup_context)
      @lookup_context = lookup_context
    end

    def render
      raise NotImplementedError
    end

    module ObjectRendering # :nodoc:
      PREFIXED_PARTIAL_NAMES = Concurrent::Map.new do |h, k|
        h[k] = Concurrent::Map.new
      end

      def initialize(lookup_context, options)
        super
        @context_prefix = lookup_context.prefixes.first
      end

      private
        def local_variable(path)
          if as = @options[:as]
            raise_invalid_option_as(as) unless /\A[a-z_]\w*\z/.match?(as.to_s)
            as.to_sym
          else
            begin
              base = path.end_with?("/") ? "" : File.basename(path)
              raise_invalid_identifier(path) unless base =~ /\A_?(.*?)(?:\.\w+)*\z/
              $1.to_sym
            end
          end
        end

        IDENTIFIER_ERROR_MESSAGE = "The partial name (%s) is not a valid Ruby identifier; " \
                                   "make sure your partial name starts with underscore."

        OPTION_AS_ERROR_MESSAGE  = "The value (%s) of the option `as` is not a valid Ruby identifier; " \
                                   "make sure it starts with lowercase letter, " \
                                   "and is followed by any combination of letters, numbers and underscores."

        def raise_invalid_identifier(path)
          raise ArgumentError, IDENTIFIER_ERROR_MESSAGE % path
        end

        def raise_invalid_option_as(as)
          raise ArgumentError, OPTION_AS_ERROR_MESSAGE % as
        end

        # Obtains the path to where the object's partial is located. If the object
        # responds to +to_partial_path+, then +to_partial_path+ will be called and
        # will provide the path. If the object does not respond to +to_partial_path+,
        # then an +ArgumentError+ is raised.
        #
        # If +prefix_partial_path_with_controller_namespace+ is true, then this
        # method will prefix the partial paths with a namespace.
        def partial_path(object, view)
          object = object.to_model if object.respond_to?(:to_model)

          path = if object.respond_to?(:to_partial_path)
            object.to_partial_path
          else
            raise ArgumentError.new("'#{object.inspect}' is not an ActiveModel-compatible object. It must implement :to_partial_path.")
          end

          if view.prefix_partial_path_with_controller_namespace
            PREFIXED_PARTIAL_NAMES[@context_prefix][path] ||= merge_prefix_into_object_path(@context_prefix, path.dup)
          else
            path
          end
        end

        def merge_prefix_into_object_path(prefix, object_path)
          if prefix.include?(?/) && object_path.include?(?/)
            prefixes = []
            prefix_array = File.dirname(prefix).split("/")
            object_path_array = object_path.split("/")[0..-3] # skip model dir & partial

            prefix_array.each_with_index do |dir, index|
              break if dir == object_path_array[index]
              prefixes << dir
            end

            (prefixes << object_path).join("/")
          else
            object_path
          end
        end
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
      attr_reader :body, :template

      def initialize(body, template)
        @body = body
        @template = template
      end

      def format
        template.format
      end

      EMPTY_SPACER = Struct.new(:body).new
    end

    private
      NO_DETAILS = {}.freeze

      def extract_details(options) # :doc:
        details = nil
        @lookup_context.registered_details.each do |key|
          value = options[key]

          if value
            (details ||= {})[key] = Array(value)
          end
        end
        details || NO_DETAILS
      end

      def prepend_formats(formats) # :doc:
        formats = Array(formats)
        return if formats.empty?

        @lookup_context.formats = formats | @lookup_context.formats
      end

      def build_rendered_template(content, template)
        RenderedTemplate.new content, template
      end

      def build_rendered_collection(templates, spacer)
        RenderedCollection.new templates, spacer
      end
  end
end
