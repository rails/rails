module AbstractController
  module Layouts
    def _render_template(template, options)
      _action_view._render_template_with_layout(template, options[:_layout])
    end
  end
end