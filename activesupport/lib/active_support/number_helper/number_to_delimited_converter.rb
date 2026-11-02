# :markup: markdown
# frozen_string_literal: true

require "active_support/number_helper/number_converter"

module ActiveSupport
  module NumberHelper
    class NumberToDelimitedConverter < NumberConverter # :nodoc:
      self.validate_float = true

      def convert
        number_string = number.to_s
        return number_string if number.respond_to?(:finite?) && !number.finite?

        if number_string.include?(".")
          left, right = number_string.split(".")
        else
          # Integers are by far the most common input, and their to_s is a
          # fresh String that can be delimited in place. A String number is
          # the caller's own object, so copy it, into a plain String as split
          # would have produced, whatever subclass it was.
          left = number.is_a?(::String) ? ::String.new(number_string) : number_string
        end

        if delimiter_pattern
          left.gsub!(delimiter_pattern) do |digit_to_delimit|
            "#{digit_to_delimit}#{options[:delimiter]}"
          end
        elsif (delimiter = options[:delimiter])
          # Insert the delimiter every three digits from the right, so that
          # earlier insertion points stay valid and no group strings are built.
          first_digit = left.start_with?("-", "+") ? 1 : 0
          position = left.size - 3
          while position > first_digit
            left.insert(position, delimiter)
            position -= 3
          end
        end

        right ? "#{left}#{options[:separator]}#{right}" : left
      end

      private
        def delimiter_pattern
          options[:delimiter_pattern]
        end
    end
  end
end
