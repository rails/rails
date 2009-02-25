module AbstractController
  module Renderer
    
    def self.included(klass)
      klass.extend ClassMethods
      klass.extlib_inheritable_accessor :view_paths
      klass.view_paths ||= ActionView::PathSet.new
    end
    
    def _action_view
      @_action_view ||= ActionView::Base.new(self.class.view_paths, {}, self)      
    end
    
    def render(template)
      tmp = view_paths.find_by_parts(template)
      self.response_body = _action_view._render_template_with_layout(tmp)
    end
    
    module ClassMethods
      def append_view_path(path)
        self.view_paths << path
      end
    end
  end
end