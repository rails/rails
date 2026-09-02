# frozen_string_literal: true

require "concurrent/map"

module ActionView
  class Template
    # = Action View Renderable Template for objects that respond to #render_in
    class Renderable # :nodoc:
      RENDER_IN_ARITY = Concurrent::Map.new
      FORMAT_RESPONDER = Concurrent::Map.new
      private_constant :RENDER_IN_ARITY, :FORMAT_RESPONDER

      def initialize(renderable, &block)
        @renderable = renderable
        @block = block
      end

      attr_writer :renderable, :block # :nodoc:

      def identifier
        @renderable.class.name
      end

      def render(context, locals)
        klass = @renderable.class
        arity = if klass.method_defined?(:render_in)
          RENDER_IN_ARITY.fetch_or_store(klass) do
            klass.instance_method(:render_in).arity
          end
        else
          Kernel.instance_method(:method).bind_call(@renderable, :render_in).arity
        end

        if arity == 1
          ActionView.deprecator.warn <<~WARN
            Action View support for #render_in without options is deprecated.

            Change #render_in to accept keyword arguments.
          WARN

          @renderable.render_in(context, &@block)
        else
          @renderable.render_in(context, locals: locals, &@block)
        end
      rescue NameError
        if !@renderable.respond_to?(:render_in)
          raise ArgumentError, "'#{@renderable.inspect}' is not a renderable object. It must implement #render_in."
        else
          raise
        end
      end

      def format
        klass = @renderable.class
        responds = if klass.method_defined?(:format)
          FORMAT_RESPONDER.fetch_or_store(klass) { true }
        else
          @renderable.respond_to?(:format)
        end
        responds ? @renderable.format : nil
      end
    end
  end
end
