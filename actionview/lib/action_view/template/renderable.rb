# frozen_string_literal: true

module ActionView
  # = Action View Renderable Template for objects that respond to #render_in
  class Template
    class Renderable # :nodoc:
      def initialize(renderable, block)
        @renderable = renderable
        @block = block
      end

      def identifier
        @renderable.class.name
      end

      def render(context, *args)
        @renderable.render_in(context, &@block)
      end

      def format
        @renderable.format
      end
    end
  end
end
