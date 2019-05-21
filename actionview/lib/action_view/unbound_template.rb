# frozen_string_literal: true

require "concurrent/map"

module ActionView
  class UnboundTemplate
    def initialize(source, identifer, handler, options)
      @source = source
      @identifer = identifer
      @handler = handler
      @options = options

      @templates = Concurrent::Map.new(initial_capacity: 2)
    end

    def bind_locals(locals)
      @templates[locals] ||= build_template(locals)
    end

    private

      def build_template(locals)
        options = @options.merge(locals: locals)
        Template.new(
          @source,
          @identifer,
          @handler,
          options
        )
      end
  end
end
