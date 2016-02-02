module ActionView
  # This is the main entry point for rendering. It basically delegates
  # to other objects like TemplateRenderer and PartialRenderer which
  # actually renders the template.
  class Renderer
    attr_accessor :lookup_context

    def initialize(lookup_context)
      @lookup_context = lookup_context
    end

    # Main render entry point shared by AV and AC.
    def render(context, options)
      if (options.is_a?(HashWithIndifferentAccess) && !options.respond_to?(:permitted?)) ||
         (options.respond_to?(:permitted?) && !options.permitted?)
        raise ArgumentError, "render parameters are not permitted"
      end

      if options.key?(:partial)
        render_partial(context, options)
      else
        render_template(context, options)
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

    # Direct accessor to template rendering.
    def render_template(context, options) #:nodoc:
      _template_renderer.render(context, options)
    end

    # Direct access to partial rendering.
    def render_partial(context, options, &block) #:nodoc:
      _partial_renderer.render(context, options, block)
    end

    private

    def _template_renderer #:nodoc:
      @_template_renderer ||= TemplateRenderer.new(@lookup_context)
    end

    def _partial_renderer #:nodoc:
      @_partial_renderer ||= PartialRenderer.new(@lookup_context)
    end
  end
end
