module ActiveSupport
  module NumberHelper
    class NumberToPhoneConverter < NumberConverter
      def convert
        str = ''
        str << country_code(opts[:country_code])
        str << convert_to_phone_number(@number.to_s.strip)
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
          number.gsub(/(\d{1,3})(\d{3})(\d{4}$)/,"(\\1) \\2#{delimiter}\\3")
        end

        def convert_without_area_code(number)
          number.tap { |n|
            n.gsub!(/(\d{0,3})(\d{3})(\d{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
            n.slice!(0, 1) if begins_with_delimiter?(n)
          }
        end

        def begins_with_delimiter?(number)
          number.start_with?(delimiter) && !delimiter.blank?
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

