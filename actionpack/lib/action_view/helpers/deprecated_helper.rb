module ActionView
  module Helpers
    module PrototypeHelper

      def update_element_function(element_id, options = {}, &block)
        content = escape_javascript(options[:content] || '')
        content = escape_javascript(capture(&block)) if block
        
        javascript_function = case (options[:action] || :update)
          when :update
            if options[:position]
              "new Insertion.#{options[:position].to_s.camelize}('#{element_id}','#{content}')"
            else
              "$('#{element_id}').innerHTML = '#{content}'"
            end
          
          when :empty
            "$('#{element_id}').innerHTML = ''"
          
          when :remove
            "Element.remove('#{element_id}')"
          
          else
            raise ArgumentError, "Invalid action, choose one of :update, :remove, :empty"
        end
        
        javascript_function << ";\n"
        options[:binding] ? concat(javascript_function, options[:binding]) : javascript_function
      end
      deprecate :update_element_function => "use RJS instead"
      
    end
  end
end