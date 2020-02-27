# frozen_string_literal: true

module ActionView
  class ObjectRenderer < PartialRenderer # :nodoc:
    include ObjectRendering

    def render_object_with_partial(object, partial, context, block)
      @object = object
      render(partial, context, block)
    end

    def render_object_derive_partial(object, context, block)
      path = partial_path(object, context)
      render_object_with_partial(object, path, context, block)
    end

    private

      def render_partial_template(view, locals, template, layout, block)
        as     = template.variable
        locals[as] = @object
        super(view, locals, template, layout, block)
      end
  end
end
