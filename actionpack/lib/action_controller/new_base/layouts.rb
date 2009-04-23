module ActionController
  module Layouts
    depends_on ActionController::Renderer
    depends_on AbstractController::Layouts
    
    module ClassMethods
      def _implied_layout_name
        controller_path
      end
    end
    
    def render_to_body(options)
      # render :text => ..., :layout => ...
      # or
      # render :anything_else
      if !options.key?(:text) || options.key?(:layout)
        options[:_layout] = options.key?(:layout) ? _layout_for_option(options[:layout]) : _default_layout
      end
      
      super
    end
    
  private
  
    def _layout_for_option(name)
      case name
      when String     then _layout_for_name(name)
      when true       then _default_layout(true)
      when false, nil then nil
      else
        raise ArgumentError, 
          "String, true, or false, expected for `layout'; you passed #{name.inspect}"        
      end
    end
    
  end
end
