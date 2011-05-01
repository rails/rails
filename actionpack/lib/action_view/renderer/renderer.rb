module ActionView
  # This is the main entry point for rendering. It basically delegates
  # to other objects like TemplateRenderer and PartialRenderer which
  # actually renders the template.
  class Renderer
    attr_accessor :lookup_context

    # TODO: render_context should not be an initialization parameter
    def initialize(lookup_context, render_context)
      @render_context = render_context
      @lookup_context = lookup_context
      @view_flow = OutputFlow.new
    end

    # Returns the result of a render that's dictated by the options hash. The primary options are:
    #
    # * <tt>:partial</tt> - See ActionView::Partials.
    # * <tt>:file</tt> - Renders an explicit template file (this used to be the old default), add :locals to pass in those.
    # * <tt>:inline</tt> - Renders an inline template similar to how it's done in the controller.
    # * <tt>:text</tt> - Renders the text passed in out.
    #
    # If no options hash is passed or :update specified, the default is to render a partial and use the second parameter
    # as the locals hash.
    def render(options = {}, locals = {}, &block)
      case options
      when Hash
        if block_given?
          _render_partial(options.merge(:partial => options[:layout]), &block)
        elsif options.key?(:partial)
          _render_partial(options)
        else
          _render_template(options)
        end
      else
        _render_partial(:partial => options, :locals => locals)
      end
    end

    # Render but returns a valid Rack body. If fibers are defined, we return
    # a streaming body that renders the template piece by piece.
    #
    # Note that partials are not supported to be rendered with streaming,
    # so in such cases, we just wrap them in an array.
    def render_body(options)
      if options.key?(:partial)
        [_render_partial(options)]
      else
        StreamingTemplateRenderer.new(@render_context, @lookup_context).render(options)
      end
    end

    private

    def _render_template(options) #:nodoc:
      _template_renderer.render(options)
    end

    def _template_renderer #:nodoc:
      @_template_renderer ||= TemplateRenderer.new(@render_context, @lookup_context)
    end

    def _render_partial(options, &block) #:nodoc:
      _partial_renderer.setup(options, block).render
    end

    def _partial_renderer #:nodoc:
      @_partial_renderer ||= PartialRenderer.new(@render_context, @lookup_context)
    end
  end
end