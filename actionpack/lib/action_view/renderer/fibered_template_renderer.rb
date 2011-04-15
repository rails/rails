require 'action_view/renderer/template_renderer'
require 'fiber'

module ActionView
  class FiberedTemplateRenderer < TemplateRenderer #:nodoc:
    # Renders the given template. An string representing the layout can be
    # supplied as well.
    def render_template(template, layout_name = nil, locals = {}) #:nodoc:
      view, locals = @view, locals || {}

      final = nil
      layout  = layout_name && find_layout(layout_name, locals.keys)
      yielder = lambda { |*name| view._layout_for(*name) }

      instrument(:template, :identifier => template.identifier, :layout => layout.try(:virtual_path)) do
        @fiber = Fiber.new do
          final = if layout
            layout.render(view, locals, &yielder)
          else
            view._layout_for
          end
        end

        @view._view_flow = FiberedFlow.new(view._view_flow, @fiber)
        @fiber.resume

        content = template.render(view, locals, &yielder)
        view._view_flow.set(:layout, content)
        @fiber.resume while @fiber.alive?
      end

      final
    end
  end
end
