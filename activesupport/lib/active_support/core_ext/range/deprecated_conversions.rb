# frozen_string_literal: true

module ActiveSupport
  module DeprecatedRangeWithFormat # :nodoc:
    NOT_SET = Object.new # :nodoc:
    def to_s(format = NOT_SET)
      if formatter = RangeWithFormat::RANGE_FORMATS[format]
        ActiveSupport::Deprecation.warn(
          "Range#to_s(#{format.inspect}) is deprecated. Please use Range#to_fs(#{format.inspect}) instead."
        )
        formatter.call(first, last)
      elsif format == NOT_SET
        super()
      else
        ActiveSupport::Deprecation.warn(
          "Range#to_s(#{format.inspect}) is deprecated. Please use Range#to_fs(#{format.inspect}) instead."
        )
        super()
      end
    end
    alias_method :to_default_s, :to_s
    deprecate :to_default_s
  end
end

Range.prepend(ActiveSupport::DeprecatedRangeWithFormat)
