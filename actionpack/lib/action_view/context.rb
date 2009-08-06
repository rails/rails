module ActionView
  module CompiledTemplates #:nodoc:
    # holds compiled template code
  end

  # ActionView contexts are supplied to ActionController
  # to render template. The default ActionView context
  # is ActionView::Base.
  #
  # In order to work with ActionController, a Context
  # must implement:
  #
  # Context.for_controller[controller] Create a new ActionView instance for a
  #   controller
  # Context#render_partial[options]
  #   - responsible for setting options[:_template]
  #   - Returns String with the rendered partial
  #   options<Hash>:: see _render_partial in ActionView::Base
  # Context#render_template[template, layout, options, partial]
  #   - Returns String with the rendered template
  #   template<ActionView::Template>:: The template to render
  #   layout<ActionView::Template>:: The layout to render around the template
  #   options<Hash>:: See _render_template_with_layout in ActionView::Base
  #   partial<Boolean>:: Whether or not the template to render is a partial
  #
  # An ActionView context can also mix in ActionView's
  # helpers. In order to mix in helpers, a context must
  # implement:
  #
  # Context#controller
  # - Returns an instance of AbstractController
  #
  # In any case, a context must mix in ActionView::Context,
  # which stores compiled template and provides the output
  # buffer.
  module Context
    include CompiledTemplates
    attr_accessor :output_buffer

    def convert_to_model(object)
      object.respond_to?(:to_model) ? object.to_model : object
    end
  end
end