# frozen_string_literal: true

module ActiveSupport
  module NumberHelper
    class RoundingHelper # :nodoc:
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def round(number)
        return number unless precision
        number = convert_to_decimal(number)
        if significant && precision > 0
          round_significant(number)
        else
          round_without_significant(number)
        end
      end

      def digit_count(number)
        return 1 if number.zero?
        (Math.log10(absolute_number(number)) + 1).floor
      end

      private
        def round_without_significant(number)
          number = number.round(precision, BigDecimal.mode(BigDecimal::ROUND_MODE))
          number = number.to_i if precision == 0 && number.finite?
          number = number.abs if number.zero? # prevent showing negative zeros
          number
        end

        def round_significant(number)
          return 0 if number.zero?
          digits = digit_count(number)
          multiplier = 10**(digits - precision)
          (number / BigDecimal(multiplier.to_f.to_s)).round * multiplier
        end

        def convert_to_decimal(number)
          case number
          when Float, String
            BigDecimal(number.to_s)
          when Rational
            BigDecimal(number, digit_count(number.to_i) + precision)
          else
            number.to_d
          end
        end

        def precision
          options[:precision]
        end

        def significant
          options[:significant]
        end

        def absolute_number(number)
          number.respond_to?(:abs) ? number.abs : number.to_d.abs
        end
    end
  end
end
