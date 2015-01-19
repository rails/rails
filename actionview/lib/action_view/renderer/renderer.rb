module ActionView
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
    include ActionView::Helpers::JavaScriptHelper
    include ActionView::Helpers::JSDebugHelper

    attr_accessor :lookup_context
    cattr_accessor :debug_js

    def initialize(lookup_context)
      @lookup_context = lookup_context
      @partials = []
    end

    # Main render entry point shared by AV and AC.
    def render(context, options)
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
      renderer =  TemplateRenderer.new(@lookup_context)
      output   =  renderer.render(context, options)
      output   =  js_debug(output, renderer.template.path) if @@debug_js && @lookup_context.rendered_format == :js
      output
    end

    # Direct access to partial rendering.
    def render_partial(context, options, &block) #:nodoc:
      renderer  =  PartialRenderer.new(@lookup_context)
      output    =  renderer.render(context, options, block)
      @partials << [renderer.template.path, output] unless renderer.template.nil?
      output
    end
  end
end
