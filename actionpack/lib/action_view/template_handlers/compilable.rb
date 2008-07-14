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

      private
        # Method to check whether template compilation is necessary.
        # The template will be compiled if the inline template or file has not been compiled yet,
        # if local_assigns has a new key, which isn't supported by the compiled code yet.
        def recompile_template?(template)
          # Unless the template has been compiled yet, compile
          # If template caching is disabled, compile
          # Always recompile inline templates
          meth = Base::CompiledTemplates.instance_method(template.method) rescue nil
          !meth || !Base.cache_template_loading || template.is_a?(InlineTemplate)
        end
    end
  end
end
