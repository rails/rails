# frozen_string_literal: true

module ActionView
  # = Action View \Renderer
  #
  # This is the main entry point for rendering. It basically delegates
  # to other objects like TemplateRenderer and PartialRenderer which
  # actually renders the template.
  #
  # The Renderer will parse the options from the +render+ or +render_body+
  # method and render a partial or a template based on the options. The
  # +TemplateRenderer+ and +PartialRenderer+ objects are wrappers which do all
  # the setup and logic necessary to render a view and a new object is created
  # each time +render+ is called.
  class Renderer
    attr_accessor :lookup_context

    def initialize(lookup_context)
      @lookup_context = lookup_context
    end

    # Main render entry point shared by Action View and Action Controller.
    def render(context, options)
      render_to_object(context, options).body
    end

    def render_to_object(context, options) # :nodoc:
      if options.key?(:partial)
        render_partial_to_object(context, options)
      else
        render_template_to_object(context, options)
      end
    end

    # Render but returns a valid Rack body. If fibers are defined, we return
    # a streaming body that renders the template piece by piece.
    #
    # Note that partials are not supported to be rendered with streaming,
    # so in such cases, we just wrap them in an array.
    def render_body(context, options)
      if options.key?(:partial)
        [render_partial(context, options)]
      else
        StreamingTemplateRenderer.new(@lookup_context).render(context, options)
      end
    end

    # Direct access to template rendering.
    def render_template(context, options) # :nodoc:
      render_template_to_object(context, options).body
    end

    # Direct access to partial rendering.
    def render_partial(context, options, &block) # :nodoc:
      render_partial_to_object(context, options, &block).body
    end

    def cache_hits # :nodoc:
      @cache_hits ||= {}
    end

    def render_template_to_object(context, options) # :nodoc:
      TemplateRenderer.new(@lookup_context).render(context, options)
    end

    def render_partial_to_object(context, options, &block) # :nodoc:
      partial = options[:partial]
      if String === partial
        collection = collection_from_options(options)

        if collection
          # Collection + Partial
          renderer = CollectionRenderer.new(@lookup_context, options)
          renderer.render_collection_with_partial(collection, partial, context, block)
        else
          if options.key?(:object)
            # Object + Partial
            renderer = ObjectRenderer.new(@lookup_context, options)
            renderer.render_object_with_partial(options[:object], partial, context, block)
          else
            # Partial
            renderer = PartialRenderer.new(@lookup_context, options)
            renderer.render(partial, context, block)
          end
        end
      else
        collection = collection_from_object(partial) || collection_from_options(options)

        if collection
          # Collection + Derived Partial
          renderer = CollectionRenderer.new(@lookup_context, options)
          renderer.render_collection_derive_partial(collection, context, block)
        else
          # Object + Derived Partial
          renderer = ObjectRenderer.new(@lookup_context, options)
          renderer.render_object_derive_partial(partial, context, block)
        end
      end
    end

    private
      def collection_from_options(options)
        if options.key?(:collection)
          collection = options[:collection]
          collection || []
        end
      end

      def collection_from_object(object)
        object if object.respond_to?(:to_ary)
      end
  end
end
