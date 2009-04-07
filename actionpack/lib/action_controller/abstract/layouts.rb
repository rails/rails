module AbstractController
  module Layouts
    
    depends_on Renderer
        
    module ClassMethods
      def layout(layout)
        unless [String, Symbol, FalseClass, NilClass].include?(layout.class)
          raise ArgumentError, "Layouts must be specified as a String, Symbol, false, or nil"
        end
        
        @_layout = layout || false # Converts nil to false
        _write_layout_method
      end
      
      def _implied_layout_name
        name.underscore
      end
      
      def _write_layout_method
        case @_layout
        when String
          self.class_eval %{def _layout() #{@_layout.inspect} end}
        when Symbol
          self.class_eval %{def _layout() #{@_layout} end}
        when false
          self.class_eval %{def _layout() end}
        else
          self.class_eval %{
            def _layout
              if view_paths.find_by_parts?("#{_implied_layout_name}", formats, "layouts")
                "#{_implied_layout_name}"
              else
                super
              end
            end
          }
        end
      end
    end
    
    def _render_template(template, options)
      _action_view._render_template_with_layout(template, options[:_layout])
    end
        
  private
  
    def _layout() end # This will be overwritten

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
    
    def _layout_for_name(name)
      view_paths.find_by_parts(name, formats, "layouts")
    end
    
    def _default_layout(require_layout = false)
      begin
        _layout_for_option(_layout)
      rescue NameError => e
        raise NoMethodError, 
          "You specified #{@_layout.inspect} as the layout, but no such method was found"
      end
    end
  end
end