module ActionView
  class Compiler
    def self.compile_template(template)
      new(template).compile
    end

    def initialize(template)
      @template = template
    end

    def compile
      source = @template.source
      code = @template.handler.call(@template)
      virtual_path = @template.virtual_path
      compiled_template = Class.new

      # Make sure that the resulting String to be evalled is in the
      # encoding of the code
      source = <<-end_src
        def initialize(view)
          @view = view
          @view_flow = view.view_flow
          @virtual_path = #{virtual_path.inspect}
          @output_buffer = view.output_buffer

          if view.respond_to?(:assigns)
            view.assigns.each do |key, value|
              instance_variable_set("@\#{key}", value)
            end
          end
        end

        def render(local_assigns, output_buffer)
          _old_virtual_path, @view.virtual_path = @view.virtual_path, @virtual_path;_old_output_buffer = @output_buffer;#{locals_code};#{code}
        ensure
          @view.virtual_path, @output_buffer = _old_virtual_path, _old_output_buffer
        end

        def method_missing(method, *args, &block)
          @view.send(method, *args, &block)
        end
      end_src

      # Make sure the source is in the encoding of the returned code
      source.force_encoding(code.encoding)

      # In case we get back a String from a handler that is not in
      # BINARY or the default_internal, encode it to the default_internal
      source.encode!

      # Now, validate that the source we got back from the template
      # handler is valid in the default_internal. This is for handlers
      # that handle encoding but screw up
      unless source.valid_encoding?
        raise WrongEncodingError.new(@source, Encoding.default_internal)
      end

      compiled_template.class_eval(source)
      compiled_template
    end

    private

    def locals_code #:nodoc:
      # Double assign to suppress the dreaded 'assigned but unused variable' warning
      @template.locals.map { |key| "#{key} = #{key} = local_assigns[:#{key}];" }.join
    end
  end
end
