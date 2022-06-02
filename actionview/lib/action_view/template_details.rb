# frozen_string_literal: true

module ActionView
  class TemplateDetails # :nodoc:
    class Requested
      attr_reader :locale, :handlers, :formats, :variants
      attr_reader :locale_idx, :handlers_idx, :formats_idx, :variants_idx

      ANY_HASH = Hash.new(1).merge(nil => 0).freeze

      def initialize(locale:, handlers:, formats:, variants:)
        @locale = locale
        @handlers = handlers
        @formats = formats
        @variants = variants

        @locale_idx   = build_idx_hash(locale)
        @handlers_idx = build_idx_hash(handlers)
        @formats_idx  = build_idx_hash(formats)
        if variants == :any
          @variants_idx = ANY_HASH
        else
          @variants_idx = build_idx_hash(variants)
        end
      end

      private
        def build_idx_hash(arr)
          [*arr, nil].each_with_index.to_h.freeze
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
      requested.formats_idx[@format] &&
        requested.locale_idx[@locale] &&
        requested.variants_idx[@variant] &&
        requested.handlers_idx[@handler]
    end

    def sort_key_for(requested)
      [
        requested.formats_idx[@format],
        requested.locale_idx[@locale],
        requested.variants_idx[@variant],
        requested.handlers_idx[@handler]
      ]
    end

    def handler_class
      Template.handler_for_extension(handler)
    end

    def format_or_default
      format || handler_class.try(:default_format)
    end
  end
end
