module AbstractController
  module Layouts
    
    def self.included(base)
      base.extend ClassMethods
    end
    
    module ClassMethods
      def layout(layout)
        unless [String, Symbol, FalseClass, NilClass].include?(layout.class)
          raise ArgumentError, "Layouts must be specified as a String, Symbol, false, or nil"
        end
        
        @layout = layout || false # Converts nil to false
      end
      
      def _write_layout_method
        case @layout
        when String
          self.class_eval %{def _layout() #{@layout.inspect} end}
        when Symbol
          self.class_eval %{def _layout() #{@layout} end}
        when false
          self.class_eval %{def _layout() end}
        else
          self.class_eval %{
            def _layout
              if view_paths.find_by_parts?("#{controller_path}", formats, "layouts")
                "#{controller_path}"
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
      when String then _layout_for_name(name)
      when true   then _default_layout(true)
      when false  then nil
      end
    end
    
    def _layout_for_name(name)
      view_paths.find_by_parts(name, formats, "layouts")
    end
    
    def _default_layout(require_layout = false)
      _layout_for_option(_layout)
    end
  end
end