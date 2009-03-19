require "action_controller/abstract/logger"

module AbstractController
  module Renderer
    
    def self.included(klass)
      klass.class_eval do
        extend ClassMethods
        attr_internal :formats

        extlib_inheritable_accessor :view_paths        
        self.view_paths ||= ActionView::PathSet.new
        include AbstractController::Logger
      end
    end
    
    def _action_view
      @_action_view ||= ActionView::Base.new(self.class.view_paths, {}, self)      
    end
    
    def _prefix
    end
    
    def render(template = action_name)
      self.response_body = render_to_string(template)
    end
    
    def render_to_string(template = action_name, prefix = true)
      tmp = view_paths.find_by_parts(template.to_s, formats, (_prefix if prefix))
      _render_template(tmp)
    end

    def _render_template(tmp)
      _action_view._render_template_with_layout(tmp)
    end

    module ClassMethods
      def append_view_path(path)
        self.view_paths << path
      end
    end
  end
end