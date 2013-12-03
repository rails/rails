module ActiveSupport
  module NumberHelper
    class NumberToRoundedConverter < NumberConverter # :nodoc:
      self.namespace      = :precision
      self.validate_float = true

      def convert
        @number = Float(number)

        precision = options.delete :precision
        significant = options.delete :significant

        if significant && precision > 0
          digits, rounded_number = digits_and_rounded_number(precision)
          precision -= digits
          precision = 0 if precision < 0 # don't let it be negative
        else
          rounded_number = BigDecimal.new(number.to_s).round(precision).to_f
          rounded_number = rounded_number.abs if rounded_number.zero? # prevent showing negative zeros
        end

        delimited_number = NumberToDelimitedConverter.convert("%01.#{precision}f" % rounded_number, options)
        format_number(delimited_number)
      end

      private

        def digits_and_rounded_number(precision)
          if number.zero?
            [1, 0]
          else
            digits = digit_count(number)
            multiplier = 10 ** (digits - precision)
            rounded_number = calculate_rounded_number(multiplier)
            digits = digit_count(rounded_number) # After rounding, the number of digits may have changed
            [digits, rounded_number]
          end
        end

        def calculate_rounded_number(multiplier)
          (BigDecimal.new(number.to_s) / BigDecimal.new(multiplier.to_f.to_s)).round.to_f * multiplier
        end

        def digit_count(number)
          (Math.log10(number.abs) + 1).floor
        end

        def strip_insignificant_zeros
          options[:strip_insignificant_zeros]
        end

        def format_number(number)
          if strip_insignificant_zeros
            escaped_separator = Regexp.escape(options[:separator])
            number.sub(/(#{escaped_separator})(\d*[1-9])?0+\z/, '\1\2').sub(/#{escaped_separator}\z/, '')
          else
            number
          end
        end
    end
  end
end
