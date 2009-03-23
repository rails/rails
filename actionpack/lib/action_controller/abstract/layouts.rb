module AbstractController
  module Layouts
    
    def self.included(base)
      base.extend ClassMethods
    end
    
    module ClassMethods
      def _layout() end
    end
    
    def _render_template(template, options)
      _action_view._render_template_with_layout(template, options[:_layout])
    end
        
  private
    
    def _layout_for_option(name)
      case name
      when String then _layout_for_name(name)
      when true   then _default_layout(true)
      when false  then nil
      end
    end
    
    def _layout_for_name(name)
      view_paths.find_by_parts(name, formats, "layouts")
    end
    
    def _default_layout(require_layout = false)
      # begin
      #   _layout_for_name(controller_path)
      # rescue ActionView::MissingTemplate
      #   begin
      #     _layout_for_name("application")
      #   rescue ActionView::MissingTemplate => e
      #     raise e if require_layout
      #   end
      # end
      _layout_for_option(self.class._layout)
    end
  end
end