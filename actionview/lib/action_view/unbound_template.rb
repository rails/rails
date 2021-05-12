# frozen_string_literal: true

require "concurrent/map"

module ActionView
  class UnboundTemplate
    attr_reader :handler, :format, :variant, :locale, :virtual_path

    def initialize(source, identifier, handler, format:, variant:, locale:, virtual_path:)
      @source = source
      @identifier = identifier
      @handler = handler

      @format = format
      @variant = variant
      @locale = locale
      @virtual_path = virtual_path

      @templates = Concurrent::Map.new(initial_capacity: 2)
    end

    def bind_locals(locals)
      @templates[locals] ||= build_template(locals)
    end

    private
      def build_template(locals)
        handler = Template.handler_for_extension(@handler)
        format = @format || handler.try(:default_format)

        Template.new(
          @source,
          @identifier,
          handler,

          format: format,
          variant: @variant,
          virtual_path: @virtual_path,

          locals: locals
        )
      end
  end
end
