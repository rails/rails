# frozen_string_literal: true

# :markup: markdown
module ActionView
  class Template
    # Action View Renderable Template for objects that respond to #render_in
    # ======================================================================
    class Renderable # :nodoc:
      def initialize(renderable, &block)
        @renderable = renderable
        @block = block
      end

      def identifier
        @renderable.class.name
      end

      KERNEL_METHOD = Kernel.instance_method(:method)
      private_constant :KERNEL_METHOD

      def render(context, locals)
        @renderable.render_in(context, locals: locals, &@block)
      rescue ArgumentError
        render_in_method = KERNEL_METHOD.bind_call(@renderable, :render_in)

        if render_in_method.arity == 1
          ActionView.deprecator.warn <<~WARN
            Action View support for #render_in without options is deprecated.

            Change #render_in to accept keyword arguments.
          WARN

          @renderable.render_in(context, &@block)
        else
          raise
        end
      rescue NameError
        if !@renderable.respond_to?(:render_in)
          raise ArgumentError, "'#{@renderable.inspect}' is not a renderable object. It must implement #render_in."
        else
          raise
        end
      end

      def format
        @renderable.try(:format)
      end
    end
  end
end
