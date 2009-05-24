module AbstractController
  module Layouts
    extend ActiveSupport::DependencyModule

    depends_on Renderer

    included do
      extlib_inheritable_accessor :_layout_conditions
      self._layout_conditions = {}
    end

    module ClassMethods
      def layout(layout, conditions = {})
        unless [String, Symbol, FalseClass, NilClass].include?(layout.class)
          raise ArgumentError, "Layouts must be specified as a String, Symbol, false, or nil"
        end

        conditions.each {|k, v| conditions[k] = Array(v).map {|a| a.to_s} }
        self._layout_conditions = conditions
        
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
          self.class_eval %{def _layout(details) #{@_layout.inspect} end}
        when Symbol
          self.class_eval %{def _layout(details) #{@_layout} end}
        when false
          self.class_eval %{def _layout(details) end}
        else
          self.class_eval %{
            def _layout(details)
              if view_paths.find_by_parts?("#{_implied_layout_name}", details, "layouts")
                "#{_implied_layout_name}"
              else
                super
              end
            end
          }
        end
      end
    end
        
  private
  
    def _layout(details) end # This will be overwritten
    
    # :api: plugin
    # ====
    # Override this to mutate the inbound layout name
    def _layout_for_name(name, details = {:formats => formats})
      unless [String, FalseClass, NilClass].include?(name.class)
        raise ArgumentError, "String, false, or nil expected; you passed #{name.inspect}"
      end
      
      name && view_paths.find_by_parts(name, details, _layout_prefix(name))
    end

    # TODO: Decide if this is the best hook point for the feature
    def _layout_prefix(name)
      "layouts"
    end
    
    def _default_layout(require_layout = false, details = {:formats => formats})
      if require_layout && _action_has_layout? && !_layout(details)
        raise ArgumentError,
          "There was no default layout for #{self.class} in #{view_paths.inspect}"
      end

      begin
        _layout_for_name(_layout(details), details) if _action_has_layout?
      rescue NameError => e
        raise NoMethodError, 
          "You specified #{@_layout.inspect} as the layout, but no such method was found"
      end
    end

    def _action_has_layout?
      conditions = _layout_conditions
      if only = conditions[:only]
        only.include?(action_name)
      elsif except = conditions[:except]
        !except.include?(action_name)
      else
        true
      end
    end
  end
end