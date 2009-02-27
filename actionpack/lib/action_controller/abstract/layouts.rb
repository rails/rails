module AbstractController
  module Layouts
    def _render_template(tmp)
      _action_view._render_template_with_layout(tmp, _layout)
    end
    
    def _layout
    end
  end
end