# frozen_string_literal: true

require "active_support/number_helper/number_converter"

module ActiveSupport
  module NumberHelper
    class NumberToDelimitedConverter < NumberConverter # :nodoc:
      self.validate_float = true

      DEFAULT_DELIMITER_REGEX = /(\d)(?=(\d\d\d)+(?!\d))/

      def convert
        parts.join(options[:separator])
      end

      private
        def parts
          left, right = number.to_s.split(".")
          if delimiter_pattern
            left.gsub!(delimiter_pattern) do |digit_to_delimit|
              "#{digit_to_delimit}#{options[:delimiter]}"
            end
          else
            left_parts = []
            offset = left.size % 3
            if offset > 0
              left_parts << left[0, offset]
            end

            (left.size / 3).times do |i|
              left_parts << left[offset + (i * 3), 3]
            end

            left = left_parts.join(options[:delimiter])
          end

          [left, right].compact
        end

        def delimiter_pattern
          options.fetch(:delimiter_pattern, DEFAULT_DELIMITER_REGEX)
        end
    end
  end
end
