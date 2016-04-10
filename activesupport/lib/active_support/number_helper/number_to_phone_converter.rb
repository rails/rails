module ActiveSupport
  module NumberHelper
    class NumberToPhoneConverter < NumberConverter #:nodoc:
      def convert
        str  = country_code(opts[:country_code])
        str << convert_to_phone_number(number.to_s.strip)
        str << phone_ext(opts[:extension])
      end

      private

        def convert_to_phone_number(number)
          parts = parse(number)
          if parts
            number = opts[:area_code] && !parts[0].blank? ? "(#{parts.shift}) " : ""
            number << parts.join(delimiter)
            number.slice!(0, 1) if start_with_delimiter?(number)
          end
          number
        end

        def parse(number)
          if match_data = number.match(regexp_pattern)
            match_data.captures
          end
        end

        def start_with_delimiter?(number)
          delimiter.present? && number.start_with?(delimiter)
        end

        def delimiter
          opts[:delimiter] || "-"
        end

        def country_code(code)
          code.blank? ? "" : "+#{code}#{delimiter}"
        end

        def phone_ext(ext)
          ext.blank? ? "" : " x #{ext}"
        end

        def regexp_pattern
          opts.fetch :pattern, /(\d{0,3})(\d{3})(\d{4}$)/
        end

    end
  end
end

