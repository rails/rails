module ActionView
  module TemplateHandlers
    module Compilable
      def self.included(base)
        base.extend ClassMethod
      end

      module ClassMethod
        # If a handler is mixin this module, set compilable to true
        def compilable?
          true
        end
      end

      def render(template, local_assigns = {})
        @view.send(:execute, template, local_assigns)
      end
    end
  end
end
