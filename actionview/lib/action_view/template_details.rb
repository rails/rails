# frozen_string_literal: true

module ActionView
  class TemplateDetails # :nodoc:
    class Requested
      attr_reader :locale, :handlers, :formats, :variants

      def initialize(locale:, handlers:, formats:, variants:)
        @locale = locale
        @handlers = handlers
        @formats = formats
        @variants = variants
      end
    end

    attr_reader :locale, :handler, :format, :variant

    def initialize(locale, handler, format, variant)
      @locale = locale
      @handler = handler
      @format = format
      @variant = variant
    end

    def matches?(requested)
      return if format && !requested.formats.include?(format)
      return if locale && !requested.locale.include?(locale)
      unless requested.variants == :any
        return if variant && !requested.variants.include?(variant)
      end
      return if handler && !requested.handlers.include?(handler)

      true
    end

    def sort_key_for(requested)
      locale_match = details_match_sort_key(locale, requested.locale)
      format_match = details_match_sort_key(format, requested.formats)
      variant_match =
        if requested.variants == :any
          variant ? 1 : 0
        else
          details_match_sort_key(variant, requested.variants)
        end
      handler_match = details_match_sort_key(handler, requested.handlers)

      [locale_match, format_match, variant_match, handler_match]
    end

    def handler_class
      Template.handler_for_extension(handler)
    end

    def format_or_default
      format || handler_class.try(:default_format)
    end

    private
      def details_match_sort_key(have, want)
        if have
          want.index(have)
        else
          want.size
        end
      end
  end
end
