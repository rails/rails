module ActionView
  module Helpers
    # Provides methods for converting a number into a formatted string that currently represents
    # one of the following forms: phone number, percentage, money, or precision level.
    module NumberHelper

      # Formats a +number+ into a US phone number string. The +options+ can be a hash used to customize the format of the output.
      # The area code can be surrounded by parentheses by setting +:area_code+ to true; default is false
      # The delimiter can be set using +:delimiter+; default is "-"
      # Examples:
      #   number_to_phone(1235551234)   => 123-555-1234
      #   number_to_phone(1235551234, {:area_code => true})   => (123) 555-1234
      #   number_to_phone(1235551234, {:delimiter => " "})    => 123 555 1234
      #   number_to_phone(1235551234, {:area_code => true, :extension => 555})  => (123) 555-1234 x 555
      def number_to_phone(number, options = {})
        options   = options.stringify_keys
        area_code = options.delete("area_code") { false }
        delimiter = options.delete("delimiter") { "-" }
        extension = options.delete("extension") { "" }
        begin
          str = area_code == true ? number.to_s.gsub(/([0-9]{3})([0-9]{3})([0-9]{4})/,"(\\1) \\2#{delimiter}\\3") : number.to_s.gsub(/([0-9]{3})([0-9]{3})([0-9]{4})/,"\\1#{delimiter}\\2#{delimiter}\\3")
          extension.to_s.strip.empty? ? str : "#{str} x #{extension.to_s.strip}"
        rescue
          number
        end
      end

      # Formats a +number+ into a currency string. The +options+ hash can be used to customize the format of the output.
      # The +number+ can contain a level of precision using the +precision+ key; default is 2
      # The currency type can be set using the +unit+ key; default is "$"
      # The unit separator can be set using the +separator+ key; default is "."
      # The delimiter can be set using the +delimiter+ key; default is ","
      # Examples:
      #    number_to_currency(1234567890.50)     => $1,234,567,890.50
      #    number_to_currency(1234567890.506)    => $1,234,567,890.51
      #    number_to_currency(1234567890.50, {:unit => "&pound;", :separator => ",", :delimiter => ""}) => &pound;1234567890,50
      def number_to_currency(number, options = {})
        options = options.stringify_keys
        precision, unit, separator, delimiter = options.delete("precision") { 2 }, options.delete("unit") { "$" }, options.delete("separator") { "." }, options.delete("delimiter") { "," }
        separator = "" unless precision > 0
        begin
          parts = number_with_precision(number, precision).split('.')
          unit + number_with_delimiter(parts[0], delimiter) + separator + parts[1].to_s
        rescue
          number
        end
      end

      # Formats a +number+ as into a percentage string. The +options+ hash can be used to customize the format of the output.
      # The +number+ can contain a level of precision using the +precision+ key; default is 3
      # The unit separator can be set using the +separator+ key; default is "."
      # Examples:
      #   number_to_percentage(100)    => 100.000%
      #   number_to_percentage(100, {:precision => 0}) => 100%
      #   number_to_percentage(302.0574, {:precision => 2})  => 302.06%
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

      # Formats a +number+ with a +delimiter+.
      # Example:
      #    number_with_delimiter(12345678) => 12,345,678
      def number_with_delimiter(number, delimiter=",")
        number.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
      end

      # Returns a formatted-for-humans file size.
      # 
      # Examples:
      #   human_size(123)          => 123 Bytes
      #   human_size(1234)         => 1.2 KB
      #   human_size(12345)        => 12.1 KB
      #   human_size(1234567)      => 1.2 MB
      #   human_size(1234567890)   => 1.1 GB
      def number_to_human_size(size)
        case 
          when size < 1.kilobyte: '%d Bytes' % size
          when size < 1.megabyte: '%.1f KB'  % (size / 1.0.kilobyte)
          when size < 1.gigabyte: '%.1f MB'  % (size / 1.0.megabyte)
          when size < 1.terabyte: '%.1f GB'  % (size / 1.0.gigabyte)
          else                    '%.1f TB'  % (size / 1.0.terabyte)
        end.sub('.0', '')
      rescue
        nil
      end
      
      alias_method :human_size, :number_to_human_size # deprecated alias

      # Formats a +number+ with a level of +precision+.
      # Example:
      #    number_with_precision(111.2345) => 111.235
      def number_with_precision(number, precision=3)
        sprintf("%01.#{precision}f", number)
      end
    end
  end
end
