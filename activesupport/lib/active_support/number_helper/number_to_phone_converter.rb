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
          if opts[:area_code]
            convert_with_area_code(number)
          else
            convert_without_area_code(number)
          end
        end

        def convert_with_area_code(number)
          number.gsub!(/(\d{1,3})(\d{3})(\d{4}$)/,"(\\1) \\2#{delimiter}\\3")
          number
        end

        def convert_without_area_code(number)
          number.gsub!(/(\d{0,3})(\d{3})(\d{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
          number.slice!(0, 1) if start_with_delimiter?(number)
          number
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
    end
  end
end

