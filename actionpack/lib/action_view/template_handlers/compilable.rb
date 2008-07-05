module ActionView
  module TemplateHandlers
    module Compilable
      def self.included(base)
        base.extend ClassMethod

        # Map method names to the names passed in local assigns so far
        base.cattr_accessor :template_args
        base.template_args = {}
      end

      module ClassMethod
        # If a handler is mixin this module, set compilable to true
        def compilable?
          true
        end
      end

      def render(template)
        @view.send :execute, template
      end

      # Compile and evaluate the template's code
      def compile_template(template)
        return false unless compile_template?(template)

        render_symbol = assign_method_name(template)
        render_source = create_template_source(template, render_symbol)

        begin
          file_name = template.filename || 'compiled-template'
          ActionView::Base::CompiledTemplates.module_eval(render_source, file_name, 0)
        rescue Exception => e  # errors from template code
          if Base.logger
            Base.logger.debug "ERROR: compiling #{render_symbol} RAISED #{e}"
            Base.logger.debug "Function body: #{render_source}"
            Base.logger.debug "Backtrace: #{e.backtrace.join("\n")}"
          end

          raise ActionView::TemplateError.new(template, @view.assigns, e)
        end
      end

      private
        # Method to check whether template compilation is necessary.
        # The template will be compiled if the inline template or file has not been compiled yet,
        # if local_assigns has a new key, which isn't supported by the compiled code yet.
        def compile_template?(template)
          # Unless the template has been complied yet, compile
          return true unless render_symbol = @view.method_names[template.method_key]

          # If template caching is disabled, compile
          return true unless Base.cache_template_loading

          # Always recompile inline templates
          return true if template.is_a?(InlineTemplate)

          # Unless local assigns support, recompile
          return true unless supports_local_assigns?(render_symbol, template.locals)

          # Otherwise, use compiled method
          return false
        end

        def assign_method_name(template)
          @view.method_names[template.method_key] ||= template.method_name
        end

        # Method to create the source code for a given template.
        def create_template_source(template, render_symbol)
          body = compile(template)

          self.template_args[render_symbol] ||= {}
          locals_keys = self.template_args[render_symbol].keys | template.locals.keys
          self.template_args[render_symbol] = locals_keys.inject({}) { |h, k| h[k] = true; h }

          locals_code = ""
          locals_keys.each do |key|
            locals_code << "#{key} = local_assigns[:#{key}];"
          end

          source = <<-end_src
            def #{render_symbol}(local_assigns)
              old_output_buffer = output_buffer;#{locals_code};#{body}
            ensure
              self.output_buffer = old_output_buffer
            end
          end_src

          return source
        end

        # Return true if the given template was compiled for a superset of the keys in local_assigns
        def supports_local_assigns?(render_symbol, local_assigns)
          local_assigns.empty? ||
            ((args = self.template_args[render_symbol]) && local_assigns.all? { |k,_| args.has_key?(k) })
        end
    end
  end
end
