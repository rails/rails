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

      def render(template)
        @view.send(:execute, template)
      end

      # Compile and evaluate the template's code
      def compile_template(template)
        return false unless recompile_template?(template)

        @@mutex.synchronize do
          locals_code = template.locals.keys.map { |key| "#{key} = local_assigns[:#{key}];" }.join

          source = <<-end_src
            def #{template.method}(local_assigns)
              old_output_buffer = output_buffer;#{locals_code};#{compile(template)}
            ensure
              self.output_buffer = old_output_buffer
            end
          end_src

          begin
            file_name = template.filename || 'compiled-template'
            ActionView::Base::CompiledTemplates.module_eval(source, file_name, 0)
          rescue Exception => e # errors from template code
            if logger = ActionController::Base.logger
              logger.debug "ERROR: compiling #{template.method} RAISED #{e}"
              logger.debug "Function body: #{source}"
              logger.debug "Backtrace: #{e.backtrace.join("\n")}"
            end

            raise ActionView::TemplateError.new(template, @view.assigns, e)
          end
        end
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
