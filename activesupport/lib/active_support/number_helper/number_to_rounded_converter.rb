module ActiveSupport
  module NumberHelper
    class NumberToRoundedConverter < NumberConverter # :nodoc:
      self.namespace      = :precision
      self.validate_float = true

      def convert
        precision = options.delete :precision

        if precision
          case number
          when Float, String
            @number = BigDecimal(number.to_s)
          when Rational
            @number = BigDecimal(number, digit_count(number.to_i) + precision)
          else
            @number = number.to_d
          end

          if options.delete(:significant) && precision > 0
            digits, rounded_number = digits_and_rounded_number(precision)
            precision -= digits
            precision = 0 if precision < 0 # don't let it be negative
          else
            rounded_number = number.round(precision)
            rounded_number = rounded_number.to_i if precision == 0 && rounded_number.finite?
            rounded_number = rounded_number.abs if rounded_number.zero? # prevent showing negative zeros
          end

          formatted_string =
            if BigDecimal === rounded_number && rounded_number.finite?
              s = rounded_number.to_s("F")
              s << "0".freeze * precision
              a, b = s.split(".".freeze, 2)
              a << ".".freeze
              a << b[0, precision]
            else
              "%00.#{precision}f" % rounded_number
            end
        else
          formatted_string = number
        end

        delimited_number = NumberToDelimitedConverter.convert(formatted_string, options)
        format_number(delimited_number)
      end

      private

        def digits_and_rounded_number(precision)
          if zero?
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
          (number / BigDecimal.new(multiplier.to_f.to_s)).round * multiplier
        end

        def digit_count(number)
          number.zero? ? 1 : (Math.log10(absolute_number(number)) + 1).floor
        end

        def strip_insignificant_zeros
          options[:strip_insignificant_zeros]
        end

        def format_number(number)
          if strip_insignificant_zeros
            escaped_separator = Regexp.escape(options[:separator])
            number.sub(/(#{escaped_separator})(\d*[1-9])?0+\z/, '\1\2').sub(/#{escaped_separator}\z/, "")
          else
            number
          end
        end

        def absolute_number(number)
          number.respond_to?(:abs) ? number.abs : number.to_d.abs
        end

        def zero?
          number.respond_to?(:zero?) ? number.zero? : number.to_d.zero?
        end
    end
  end
end
