# frozen_string_literal: true

require "concurrent/map"

module ActionView
  class UnboundTemplate
    def initialize(source, identifier, handler, options)
      @source = source
      @identifier = identifier
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
          @identifier,
          @handler,
          **options
        )
      end
  end
end
