module ActionView
  module Renderable
    # NOTE: The template that this mixin is beening include into is frozen
    # So you can not set or modify any instance variables

    extend ActiveSupport::Memoizable

    def self.included(base)
      @@mutex = Mutex.new
    end

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

    def render(view, local_assigns = {})
      compile(local_assigns)

      view._first_render ||= self
      view._last_render = self

      view.send(:evaluate_assigns)
      view.send(:set_controller_content_type, mime_type) if respond_to?(:mime_type)
      view.send(:execute, method(local_assigns), local_assigns)
    end

    def method(local_assigns)
      if local_assigns && local_assigns.any?
        local_assigns_keys = "locals_#{local_assigns.keys.map { |k| k.to_s }.sort.join('_')}"
      end
      ['_run', extension, method_segment, local_assigns_keys].compact.join('_').to_sym
    end

    private
      # Compile and evaluate the template's code (if necessary)
      def compile(local_assigns)
        render_symbol = method(local_assigns)

        @@mutex.synchronize do
          if recompile?(render_symbol)
            compile!(render_symbol, local_assigns)
          end
        end
      end

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
          logger = ActionController::Base.logger
          logger.debug "Compiling template #{render_symbol}" if logger

          ActionView::Base::CompiledTemplates.module_eval(source, filename, 0)
        rescue Exception => e # errors from template code
          if logger
            logger.debug "ERROR: compiling #{render_symbol} RAISED #{e}"
            logger.debug "Function body: #{source}"
            logger.debug "Backtrace: #{e.backtrace.join("\n")}"
          end

          raise ActionView::TemplateError.new(self, {}, e)
        end
      end

      # Method to check whether template compilation is necessary.
      # The template will be compiled if the file has not been compiled yet, or
      # if local_assigns has a new key, which isn't supported by the compiled code yet.
      def recompile?(symbol)
        !(ActionView::PathSet::Path.eager_load_templates? && Base::CompiledTemplates.method_defined?(symbol))
      end
  end
end
