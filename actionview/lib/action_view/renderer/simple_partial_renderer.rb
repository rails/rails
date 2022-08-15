# frozen_string_literal: true

module ActionView
  class SimplePartialRenderer < AbstractRenderer # :nodoc:
    def initialize(lookup_context)
      super(lookup_context)
    end

    def render(view, path, locals)
      template = @lookup_context.find_partial(path, locals.keys)

      ActiveSupport::Notifications.instrument(
        "render_partial.action_view", {
          identifier: template.identifier,
          cache_hit: false
        }) do |payload|
        content = template.render(view, locals, add_to_stack: true) do |*name|
          view._layout_for(*name)
        end

        payload[:cache_hit] = view.view_renderer.cache_hits[template.virtual_path]
        build_rendered_template(content, template)
      end
    end
  end
end
