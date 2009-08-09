# encoding: utf-8
# This is so that templates compiled in this file are UTF-8

require 'set'
require "action_view/template/resolver"

module ActionView
  class Template
    extend TemplateHandlers
    attr_reader :source, :identifier, :handler, :mime_type, :formats, :details
    
    def initialize(source, identifier, handler, details)
      @source     = source
      @identifier = identifier
      @handler    = handler
      @details    = details
      @method_names = {}

      format = details.delete(:format) || begin
        # TODO: Clean this up
        handler.respond_to?(:default_format) ? handler.default_format.to_sym.to_s : "html"
      end
      @mime_type = Mime::Type.lookup_by_extension(format.to_s)
      @formats = [format.to_sym]
      @formats << :html if format == :js
      @details[:formats] = Array.wrap(format.to_sym)
    end
    
    def render(view, locals, &blk)
      method_name = compile(locals, view)
      view.send(method_name, locals, &blk)
    end
    
    # TODO: Figure out how to abstract this
    def variable_name
      @variable_name ||= identifier[%r'_?(\w+)(\.\w+)*$', 1].to_sym
    end

    # TODO: Figure out how to abstract this
    def counter_name
      @counter_name ||= "#{variable_name}_counter".to_sym
    end
    
    # TODO: kill hax
    def partial?
      @details[:partial]
    end

  private

    def compile(locals, view)
      method_name = build_method_name(locals)
      
      return method_name if view.respond_to?(method_name)
      
      locals_code = locals.keys.map! { |key| "#{key} = local_assigns[:#{key}];" }.join

      code = @handler.call(self)
      if code.sub!(/\A(#.*coding.*)\n/, '')
        encoding_comment = $1
      elsif defined?(Encoding) && Encoding.respond_to?(:default_external)
        encoding_comment = "#coding:#{Encoding.default_external}"
      end

      source = <<-end_src
        def #{method_name}(local_assigns)
          old_output_buffer = output_buffer;#{locals_code};#{code}
        ensure
          self.output_buffer = old_output_buffer
        end
      end_src

      if encoding_comment
        source = "#{encoding_comment}\n#{source}"
        line = -1
      else
        line = 0
      end

      begin
        ActionView::CompiledTemplates.module_eval(source, identifier, line)
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
      @method_names[locals.keys.hash] ||=
        "_render_template_#{@identifier.hash}_#{__id__}_#{locals.keys.hash}".gsub('-', "_")
    end
  end
end
