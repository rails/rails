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
      
      # Takes the specified layout and creates a _layout method to be called
      # by _default_layout
      # 
      # If the specified layout is a:
      # String:: return the string
      # Symbol:: call the method specified by the symbol
      # false::  return nil
      # none::   If a layout is found in the view paths with the controller's
      #          name, return that string. Otherwise, use the superclass'
      #          layout (which might also be implied)
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
              if view_paths.find_by_parts?("#{_implied_layout_name}", {:formats => formats}, "layouts")
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
    
    def _layout_for_name(name)
      unless [String, FalseClass, NilClass].include?(name.class)
        raise ArgumentError, "String, false, or nil expected; you passed #{name.inspect}"
      end
      
      name && view_paths.find_by_parts(name, {:formats => formats}, "layouts")
    end
    
    def _default_layout(require_layout = false)
      if require_layout && !_layout
        raise ArgumentError, 
          "There was no default layout for #{self.class} in #{view_paths.inspect}"
      end
        
      begin
        layout = _layout_for_name(_layout)
      rescue NameError => e
        raise NoMethodError, 
          "You specified #{@_layout.inspect} as the layout, but no such method was found"
      end
    end
  end
end