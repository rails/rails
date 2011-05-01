module ActionView
  # This is the main entry point for rendering. It basically delegates
  # to other objects like TemplateRenderer and PartialRenderer which
  # actually renders the template.
  class Renderer
    attr_accessor :lookup_context, :controller

    def initialize(lookup_context, controller)
      @lookup_context = lookup_context
      @controller = controller
    end

    def render(context, options = {}, locals = {}, &block)
      case options
      when Hash
        if block_given?
          _render_partial(context, options.merge(:partial => options[:layout]), &block)
        elsif options.key?(:partial)
          _render_partial(context, options)
        else
          _render_template(context, options)
        end
      else
        _render_partial(context, :partial => options, :locals => locals)
      end
    end

    # Render but returns a valid Rack body. If fibers are defined, we return
    # a streaming body that renders the template piece by piece.
    #
    # Note that partials are not supported to be rendered with streaming,
    # so in such cases, we just wrap them in an array.
    def render_body(context, options)
      if options.key?(:partial)
        [_render_partial(context, options)]
      else
        StreamingTemplateRenderer.new(@lookup_context, @controller).render(context, options)
      end
    end

    private

    def _render_template(context, options) #:nodoc:
      _template_renderer.render(context, options)
    end

    def _template_renderer #:nodoc:
      @_template_renderer ||= TemplateRenderer.new(@lookup_context, @controller)
    end

    def _render_partial(context, options, &block) #:nodoc:
      _partial_renderer.render(context, options, block)
    end

    def _partial_renderer #:nodoc:
      @_partial_renderer ||= PartialRenderer.new(@lookup_context, @controller)
    end
  end
end