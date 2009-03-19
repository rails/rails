module ActionController
  module Layouts
    def render_to_string(options)
      options[:_layout] = options[:layout] || _layout
      super
    end
    
    def _layout
      begin
        view_paths.find_by_parts(controller_path, formats, "layouts")
      rescue ActionView::MissingTemplate
        begin
          view_paths.find_by_parts("application", formats, "layouts")
        rescue ActionView::MissingTemplate
        end
      end
    end
  end
end