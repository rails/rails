# encoding: utf-8
# This is so that templates compiled in this file are UTF-8
require 'active_support/core_ext/array/wrap'
require 'active_support/core_ext/object/blank'

module ActionView
  class Template
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :Error
      autoload :Handler
      autoload :Handlers
      autoload :Text
    end

    extend Template::Handlers

    attr_reader :source, :identifier, :handler, :virtual_path, :formats

    def initialize(source, identifier, handler, details)
      @source     = source
      @identifier = identifier
      @handler    = handler

      @virtual_path = details[:virtual_path]
      @method_names = {}

      format   = details[:format] || :html
      @formats = Array.wrap(format).map(&:to_sym)
    end

    def render(view, locals, &block)
      # Notice that we use a bang in this instrumentation because you don't want to
      # consume this in production. This is only slow if it's being listened to.
      ActiveSupport::Notifications.instrument("action_view.render_template!", :virtual_path => @virtual_path) do
        method_name = compile(locals, view)
        view.send(method_name, locals, &block)
      end
    rescue Exception => e
      if e.is_a?(Template::Error)
        e.sub_template_of(self)
        raise e
      else
        raise Template::Error.new(self, view.assigns, e)
      end
    end

    def mime_type
      @mime_type ||= Mime::Type.lookup_by_extension(@formats.first.to_s) if @formats.first
    end

    def variable_name
      @variable_name ||= @virtual_path[%r'_?(\w+)(\.\w+)*$', 1].to_sym
    end

    def counter_name
      @counter_name ||= "#{variable_name}_counter".to_sym
    end

    def inspect
      if defined?(Rails.root)
        identifier.sub("#{Rails.root}/", '')
      else
        identifier
      end
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
            _old_virtual_path, @_virtual_path = @_virtual_path, #{@virtual_path.inspect};_old_output_buffer = output_buffer;#{locals_code};#{code}
          ensure
            @_virtual_path, self.output_buffer = _old_virtual_path, _old_output_buffer
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

          raise ActionView::Template::Error.new(self, {}, e)
        end
      end

      def build_method_name(locals)
        # TODO: is locals.keys.hash reliably the same?
        @method_names[locals.keys.hash] ||=
          "_render_template_#{@identifier.hash}_#{__id__}_#{locals.keys.hash}".gsub('-', "_")
      end
  end
end
