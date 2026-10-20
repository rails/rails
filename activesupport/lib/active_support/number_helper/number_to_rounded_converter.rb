# :markup: markdown
# frozen_string_literal: true

require "active_support/number_helper/number_converter"

module ActiveSupport
  module NumberHelper
    class NumberToRoundedConverter < NumberConverter # :nodoc:
      self.namespace      = :precision
      self.validate_float = true

      def self.separator_regexps(separator)
        escaped_separator = Regexp.escape(separator)
        [/(#{escaped_separator})(\d*[1-9])?0+\z/, /#{escaped_separator}\z/].freeze
      end

      COMMON_SEPARATOR_REGEXPS = {
        "." => separator_regexps("."),
        "," => separator_regexps(","),
      }.freeze

      def convert
        helper = RoundingHelper.new(options)
        rounded_number = helper.round(number)

        if precision = options[:precision]
          if options[:significant] && precision > 0
            digits = helper.digit_count(rounded_number)
            precision -= digits
            precision = 0 if precision < 0 # don't let it be negative
          end

          formatted_string =
            if rounded_number.finite?
              s = rounded_number.to_s("F")
              a, b = s.split(".", 2)
              if precision != 0
                b << "0" * precision
                a << "."
                a << b[0, precision]
              end
              a
            else
              # Infinity/NaN
              "%f" % rounded_number
            end
        else
          formatted_string = rounded_number
        end

        delimited_number = NumberToDelimitedConverter.convert(formatted_string, options)
        format_number(delimited_number)
      end

      private
        def strip_insignificant_zeros
          options[:strip_insignificant_zeros]
        end

        def format_number(number)
          if strip_insignificant_zeros
            insignificant_zeros, trailing_separator =
              COMMON_SEPARATOR_REGEXPS[options[:separator]] || self.class.separator_regexps(options[:separator])
            number.sub(insignificant_zeros, '\1\2').sub(trailing_separator, "")
          else
            number
          end
        end
    end
  end
end
