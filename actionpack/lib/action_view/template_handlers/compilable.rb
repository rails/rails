module ActionView
  module TemplateHandlers
    module Compilable
      def self.included(base)
        base.extend ClassMethod

        @@mutex = Mutex.new

        # Map method names to the compiled local assigns
        @@template_args = {}
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
          locals_code = ""
          locals_keys = cache_template_args(template.method, template.locals)
          locals_keys.each do |key|
            locals_code << "#{key} = local_assigns[:#{key}];"
          end

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
            if Base.logger
              Base.logger.debug "ERROR: compiling #{template.method} RAISED #{e}"
              Base.logger.debug "Function body: #{source}"
              Base.logger.debug "Backtrace: #{e.backtrace.join("\n")}"
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
          # Unless the template has been complied yet, compile
          return true unless Base::CompiledTemplates.instance_methods.include?(template.method.to_s)

          # If template caching is disabled, compile
          return true unless Base.cache_template_loading

          # Always recompile inline templates
          return true if template.is_a?(InlineTemplate)

          # Unless local assigns support, recompile
          return true unless supports_local_assigns?(template.method, template.locals)

          # Otherwise, use compiled method
          return false
        end

        def cache_template_args(render_symbol, local_assigns)
          @@template_args[render_symbol] ||= {}
          locals_keys = @@template_args[render_symbol].keys | local_assigns.keys
          @@template_args[render_symbol] = locals_keys.inject({}) { |h, k| h[k] = true; h }
          locals_keys
        end

        # Return true if the given template was compiled for a superset of the keys in local_assigns
        def supports_local_assigns?(render_symbol, local_assigns)
          local_assigns.empty? ||
            ((args = @@template_args[render_symbol]) && local_assigns.all? { |k,_| args.has_key?(k) })
        end
    end
  end
end
