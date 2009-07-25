# encoding: utf-8

module ActionView
  # NOTE: The template that this mixin is being included into is frozen
  # so you cannot set or modify any instance variables
  module Renderable #:nodoc:
    extend ActiveSupport::Memoizable

    def render(view, locals)
      compile(locals)
      view.send(method_name(locals), locals) {|*args| yield(*args) }
    end
    
    def load!
      names = CompiledTemplates.instance_methods.grep(/#{method_name_without_locals}/)
      names.each do |name|
        CompiledTemplates.class_eval do
          remove_method(name)
        end
      end
      super
    end
    
  private
  
    def filename
      'compiled-template'
    end

    def handler
      Template.handler_class_for_extension(extension)
    end
    memoize :handler

    def compiled_source
      handler.call(self)
    end
    memoize :compiled_source

    def method_name_without_locals
      ['_run', extension, method_segment].compact.join('_')
    end
    memoize :method_name_without_locals

    def method_name(local_assigns)
      if local_assigns && local_assigns.any?
        method_name = method_name_without_locals.dup
        method_name << "_locals_#{local_assigns.keys.map { |k| k.to_s }.sort.join('_')}"
      else
        method_name = method_name_without_locals
      end
      method_name.to_sym
    end

    # Compile and evaluate the template's code (if necessary)
    def compile(local_assigns)
      render_symbol = method_name(local_assigns)

      if !CompiledTemplates.method_defined?(render_symbol) || recompile?
        compile!(render_symbol, local_assigns)
      end
    end

    private
      def compile!(render_symbol, local_assigns)
        locals_code = local_assigns.keys.map { |key| "#{key} = local_assigns[:#{key}];" }.join

        source = <<-end_src
          def #{render_symbol}(local_assigns)
            old_output_buffer = output_buffer;#{locals_code};#{compiled_source}
          ensure
            self.output_buffer = old_output_buffer
          end
        end_src

        begin
          ActionView::CompiledTemplates.module_eval(source, filename.to_s, 0)
        rescue Exception => e # errors from template code
          if logger = defined?(ActionController) && Base.logger
            logger.debug "ERROR: compiling #{render_symbol} RAISED #{e}"
            logger.debug "Function body: #{source}"
            logger.debug "Backtrace: #{e.backtrace.join("\n")}"
          end

          raise ActionView::TemplateError.new(self, {}, e)
        end
      end

      def recompile?
        false
      end
  end
end
