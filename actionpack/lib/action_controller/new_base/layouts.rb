module ActionController
  module Layouts
    def render_to_string(options)
      if !options.key?(:text) || options.key?(:layout)
        options[:_layout] = options.key?(:layout) ? _layout_for_option(options[:layout]) : _layout
      end
      
      super
    end
    
    private
    
    def _layout_for_option(name)
      case name
      when String then _layout_for_name(name)
      when true   then _layout
      when false  then nil
      end
    end
    
    def _layout_for_name(name)
      view_paths.find_by_parts(name, formats, "layouts")
    end
    
    def _layout
      begin
        _layout_for_name(controller_path)
      rescue ActionView::MissingTemplate
        begin
          _layout_for_name("application")
        rescue ActionView::MissingTemplate
        end
      end
    end
  end
end