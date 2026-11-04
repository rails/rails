# frozen_string_literal: true

module ActionView
  class ObjectRenderer < PartialRenderer # :nodoc:
    include ObjectRendering

    def initialize(lookup_context, options)
      super
      @object     = nil
      @local_name = nil
    end

    def render_object_with_partial(object, partial, context, block)
      @object     = object
      @local_name = local_variable(partial)
      render(partial, context, block)
    end

    def render_object_derive_partial(object, context, block)
      path = partial_path(object, context)
      render_object_with_partial(object, path, context, block)
    end

    private
      def template_keys(path)
        super + [@local_name]
      end

      def render_partial_template(view, locals, template, layout, block)
        locals[@local_name || template.variable] = @object
        super(view, locals, template, layout, block)
      end
  end
end
