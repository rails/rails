# frozen_string_literal: true

module ActiveSupport
  module NumberHelper
    class NumberToDelimitedConverter < NumberConverter #:nodoc:
      self.validate_float = true

      DEFAULT_DELIMITER_REGEX = /(\d)(?=(\d\d\d)+(?!\d))/

      def convert(number = self.number)
        parts(number).join(options[:separator])
      end

      private

        def parts(number)
          left, right = number.to_s.split(".".freeze)
          left.gsub!(delimiter_pattern) do |digit_to_delimit|
            "#{digit_to_delimit}#{options[:delimiter]}"
          end
          [left, right].compact
        end

        def delimiter_pattern
          options.fetch(:delimiter_pattern, DEFAULT_DELIMITER_REGEX)
        end
    end
  end
end
