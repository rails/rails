module ActionController
  module Layouts
    extend ActiveSupport::DependencyModule

    depends_on ActionController::Renderer
    depends_on AbstractController::Layouts
    
    module ClassMethods
      def _implied_layout_name
        controller_path
      end
    end
    
  private

    def _determine_template(options)
      super
      if (!options.key?(:text) && !options.key?(:inline) && !options.key?(:partial)) || options.key?(:layout)
        options[:_layout] = _layout_for_option(options.key?(:layout) ? options[:layout] : :none, options[:_template].details)
      end
    end
  
    def _layout_for_option(name, details)
      case name
      when String     then _layout_for_name(name, details)
      when true       then _default_layout(true, details)
      when :none      then _default_layout(false, details)
      when false, nil then nil
      else
        raise ArgumentError, 
          "String, true, or false, expected for `layout'; you passed #{name.inspect}"        
      end
    end
    
  end
end
