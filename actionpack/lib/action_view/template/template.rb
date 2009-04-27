# encoding: utf-8
# This is so that templates compiled in this file are UTF-8

require 'set'
require "action_view/template/path"

module ActionView
  class Template
    extend TemplateHandlers
    attr_reader :source, :identifier, :handler
    
    def initialize(source, identifier, handler, details)
      @source     = source
      @identifier = identifier
      @handler    = handler
      @details    = details
    end
    
    def render(view, locals, &blk)
      method_name = compile(locals, view)
      view.send(method_name, locals, &blk)
    end
    
    # TODO: Figure out how to abstract this
    def variable_name
      identifier[%r'_?(\w+)(\.\w+)*$', 1].to_sym
    end

    # TODO: Figure out how to abstract this
    def counter_name
      "#{variable_name}_counter".to_sym
    end
    
    # TODO: kill hax
    def partial?
      @details[:partial]
    end
    
    # TODO: Move out of Template
    def mime_type
      Mime::Type.lookup_by_extension(@details[:format].to_s) if @details[:format]
    end
    
  private

    def compile(locals, view)
      method_name = build_method_name(locals)
      
      return method_name if view.respond_to?(method_name)
      
      locals_code = locals.keys.map! { |key| "#{key} = local_assigns[:#{key}];" }.join

      source = <<-end_src
        def #{method_name}(local_assigns)
          old_output_buffer = output_buffer;#{locals_code};#{@handler.call(self)}
        ensure
          self.output_buffer = old_output_buffer
        end
      end_src

      begin
        ActionView::Base::CompiledTemplates.module_eval(source, identifier, 0)
        method_name
      rescue Exception => e # errors from template code
        if logger = (view && view.logger)
          logger.debug "ERROR: compiling #{method_name} RAISED #{e}"
          logger.debug "Function body: #{source}"
          logger.debug "Backtrace: #{e.backtrace.join("\n")}"
        end

        raise ActionView::TemplateError.new(self, {}, e)
      end
    end
  
    def build_method_name(locals)
      # TODO: is locals.keys.hash reliably the same?
      "_render_template_#{@identifier.hash}_#{__id__}_#{locals.keys.hash}".gsub('-', "_")
    end
  end
end