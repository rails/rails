# frozen_string_literal: true

module ActionView
  class Template
    # = Action View Renderable Template for objects that respond to #render_in
    class Renderable # :nodoc:
      def initialize(renderable, &block)
        @renderable = renderable
        @block = block
      end

      def identifier
        @renderable.class.name
      end

      def render(context, locals)
        @renderable.render_in(context, locals: locals, &@block)
      rescue ArgumentError => error
        render_in = Kernel.instance_method(:method).bind_call(@renderable, :render_in)
        raise unless render_in.arity == 1

        raise ArgumentError, "#{identifier}#render_in must accept keyword arguments", error.backtrace
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
