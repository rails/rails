module ActionView
  module Helpers
    # Provides methods for converting a number into a formatted string that currently represents
    # one of the following forms: phone number, percentage, money, or precision level.
    module NumberHelper

      # Formats a +number+ into a US phone number string. The +options+ can be hash used to customize the format of the output.
      # The area code can be surrounded by parenthesis by setting +:area_code+ to true; default is false
      # The delimeter can be set using +:delimter+; default is "-"
      # Examples:
      #   number_to_phone(1235551234)                       => 123-555-1234
      #   number_to_phone(1235551234, {:area_code => true}) => (123) 555-1234
      #   number_to_phone(1235551234, {:delimter => " "})   => 123 555 1234
      def number_to_phone(number, options = {})
        options = options.stringify_keys
        area_code = options.delete("area_code") { false }
        delimeter = options.delete("delimeter") { "-" }
        begin
          str = number.to_s
          if area_code == true
            str.gsub!(/([0-9]{3})([0-9]{3})([0-9]{4})/,"(\\1) \\2#{delimeter}\\3")
          else
            str.gsub!(/([0-9]{3})([0-9]{3})([0-9]{4})/,"\\1#{delimeter}\\2#{delimeter}\\3")
          end
        rescue
          number
        end
      end

      # Formates a +number+ into a currency string. The +options+ hash can be used to customize the format of the output.
      # The +number+ can contain a level of precision using the +precision+ key; default is 2
      # The currency type can be set using the +unit+ key; default is "$"
      # The unit separator can be set using the +separator+ key; default is "."
      # The delimter can be set using the +delimeter+ key; default is ","
      # Examples:
      #    number_to_currency(1234567890.50)     => $1,234,567,890.50
      #    number_to_currency(1234567890.506)    => $1,234,567,890.51
      #    number_to_currency(1234567890.50, {:unit => "&pound;", :separator => ",", :delimeter => ""}) => &pound;123456789,50
      def number_to_currency(number, options = {})
        options = options.stringify_keys
        precision, unit, separator, delimeter = options.delete("precision") { 2 }, options.delete("unit") { "$" }, options.delete("separator") { "." }, options.delete("delimeter") { "," }
        begin
          parts = number_with_precision(number, precision).split('.')
          unit + number_with_delimeter(parts[0]) + separator + parts[1].to_s
        rescue
          number
        end
      end

      # Formats a +number+ as into a percentage string. The +options+ hash can be used to customize the format of the output.
      # The +number+ can contain a level of precision using the +precision+ key; default is 3
      # The unit separator can be set using the +separator+ key; default is "."
      # Examples:
      #   number_to_precision(100)    => 100.000%
      #   number_to_precision(100, {:precision => 0}) => 100%
      #   number_to_precision(302.0574, {:precision => 2})  => 302.06%
      def number_to_percentage(number, options = {})
        options = options.stringify_keys
        precision, separator = options.delete("precision") { 3 }, options.delete("separator") { "." }
        begin
          number = number_with_precision(number, precision)
          parts = number.split('.')
          if parts.at(1).nil?
            parts[0] + "%"
          else
            parts[0] + separator + parts[1].to_s + "%"
          end
        rescue
          number
        end
      end

      # Formats a +number+ with a +delimeter+.
      # Example:
      #    number_with_delimeter(12345678) => 1,235,678
      def number_with_delimeter(number, delimeter=",")
        number.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimeter}"
      end

      # Formats a +number+ with a level of +precision+.
      # Example:
      #    number_with_precision(111.2345) => 111.235
      def number_with_precision(number, precision=3)
        sprintf("%01.#{precision}f", number)
      end
    end
  end
end