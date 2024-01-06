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
        options =
          if @renderable.method(:render_in).arity == 1
            ActionView.deprecator.warn <<~WARN
              Action View support for #render_in without options is deprecated.

              Change #render_in to accept keyword arguments.
            WARN

            {}
          else
            { locals: locals }
          end

        @renderable.render_in(context, **options, &@block)
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
