# frozen_string_literal: true

module ActionView
  class SimplePartialRenderer < AbstractRenderer # :nodoc:
    def initialize(lookup_context)
      super(lookup_context)
    end

    def render_body(view, path, locals)
      template = @lookup_context.find_partial(path, locals.keys)
      template_content(view, template, locals).to_s
    end

    private

    def template_content(view, template, locals)
      ActiveSupport::Notifications.instrument(
        "render_partial.action_view", {
          identifier: template.identifier,
          cache_hit: false
        }) do |payload|
        content = template.render(view, locals, add_to_stack: true) do |*name|
          view._layout_for(*name)
        end

        payload[:cache_hit] = view.view_renderer.cache_hits[template.virtual_path]
        content
      end
    end
  end
end
