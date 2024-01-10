# frozen_string_literal: true

module ActionView
  class Template
    # = Action View Renderable Template for objects that respond to #render_in
    class Renderable # :nodoc:
      def initialize(renderable)
        @renderable = renderable
      end

      def identifier
        @renderable.class.name
      end

      def render(context, *args)
        @renderable.render_in(context)
      rescue NoMethodError
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
