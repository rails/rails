# frozen_string_literal: true

require "active_support/number_helper/number_converter"

module ActiveSupport
  module NumberHelper
    class NumberFromDelimitedConverter < NumberConverter # :nodoc:
      self.validate_float = false

      DEFAULT_DELIMITER_REGEX = /(\d)(?=(\d\d\d)+(?!\d))/

      def convert
        return if number.empty?

        left, right = parts
        "#{left}.#{right}".to_f
      end

      private
        def parts
          left, right = number.split(options[:separator])

          left.gsub!(options[:delimiter] || delimiter_pattern, "")
          [left, right].compact
        end

        def delimiter_pattern
          options.fetch(:delimiter_pattern, DEFAULT_DELIMITER_REGEX)
        end
    end
  end
end
