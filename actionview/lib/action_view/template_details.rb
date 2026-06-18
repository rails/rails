# frozen_string_literal: true

module ActionView
  class TemplateDetails # :nodoc:
    attr_reader :locale, :handler, :format, :variant

    def initialize(locale, handler, format, variant)
      @locale = locale
      @handler = handler
      @format = format
      @variant = variant
    end

    def handler_class
      Template.handler_for_extension(handler)
    end

    def format_or_default
      format || handler_class.try(:default_format)
    end
  end
end
