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
      end

      def format
        @renderable.format
      end
    end
  end
end
