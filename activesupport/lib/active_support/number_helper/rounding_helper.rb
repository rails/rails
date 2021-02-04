# frozen_string_literal: true

module ActiveSupport
  module NumberHelper
    class RoundingHelper # :nodoc:
      attr_reader :options

      def initialize(options)
        @options = options
      end

      def round(number)
        precision = absolute_precision(number)
        return number unless precision

        rounded_number = convert_to_decimal(number).round(precision, options.fetch(:round_mode, :default))
        rounded_number.zero? ? rounded_number.abs : rounded_number # prevent showing negative zeros
      end

      def digit_count(number)
        return 1 if number.zero?
        (Math.log10(number.abs) + 1).floor
      end

      private
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

        def absolute_precision(number)
          if options[:significant] && precision > 0
            precision - digit_count(convert_to_decimal(number))
          else
            precision
          end
        end

        def precision
          options[:precision] && options[:precision].to_i
        end
    end
  end
end
