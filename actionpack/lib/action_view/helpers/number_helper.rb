module ActionView
  module Helpers #:nodoc:
    # Provides methods for converting numbers into formatted strings.
    # Methods are provided for phone numbers, currency, percentage,
    # precision, positional notation, and file size.
    module NumberHelper
      # Formats a +number+ into a US phone number (e.g., (555) 123-9876). You can customize the format
      # in the +options+ hash.
      #
      # ==== Options
      # * <tt>:area_code</tt>  - Adds parentheses around the area code.
      # * <tt>:delimiter</tt>  - Specifies the delimiter to use (defaults to "-").
      # * <tt>:extension</tt>  - Specifies an extension to add to the end of the
      #   generated number.
      # * <tt>:country_code</tt>  - Sets the country code for the phone number.
      #
      # ==== Examples
      #  number_to_phone(1235551234)                                        # => 123-555-1234
      #  number_to_phone(1235551234, :area_code => true)                    # => (123) 555-1234
      #  number_to_phone(1235551234, :delimiter => " ")                     # => 123 555 1234
      #  number_to_phone(1235551234, :area_code => true, :extension => 555) # => (123) 555-1234 x 555
      #  number_to_phone(1235551234, :country_code => 1)                    # => +1-123-555-1234
      #
      #  number_to_phone(1235551234, :country_code => 1, :extension => 1343, :delimiter => ".")
      #  => +1.123.555.1234 x 1343      
      def number_to_phone(number, options = {})
        number       = number.to_s.strip unless number.nil?
        options      = options.stringify_keys
        area_code    = options["area_code"] || nil
        delimiter    = options["delimiter"] || "-"
        extension    = options["extension"].to_s.strip || nil
        country_code = options["country_code"] || nil

        begin
          str = ""
          str << "+#{country_code}#{delimiter}" unless country_code.blank?
          str << if area_code
            number.gsub!(/([0-9]{1,3})([0-9]{3})([0-9]{4}$)/,"(\\1) \\2#{delimiter}\\3")
          else
            number.gsub!(/([0-9]{1,3})([0-9]{3})([0-9]{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
          end
          str << " x #{extension}" unless extension.blank?
          str
        rescue
          number
        end
      end

      # Formats a +number+ into a currency string (e.g., $13.65). You can customize the format
      # in the +options+ hash.
      #
      # ==== Options
      # * <tt>:precision</tt>  -  Sets the level of precision (defaults to 2).
      # * <tt>:unit</tt>  - Sets the denomination of the currency (defaults to "$").
      # * <tt>:separator</tt>  - Sets the separator between the units (defaults to ".").
      # * <tt>:delimiter</tt>  - Sets the thousands delimiter (defaults to ",").
      #
      # ==== Examples
      #  number_to_currency(1234567890.50)                    # => $1,234,567,890.50
      #  number_to_currency(1234567890.506)                   # => $1,234,567,890.51
      #  number_to_currency(1234567890.506, :precision => 3)  # => $1,234,567,890.506
      #
      #  number_to_currency(1234567890.50, :unit => "&pound;", :separator => ",", :delimiter => "")
      #  # => &pound;1234567890,50
      def number_to_currency(number, options = {})
        options   = options.stringify_keys
        precision = options["precision"] || 2
        unit      = options["unit"] || "$"
        separator = precision > 0 ? options["separator"] || "." : ""
        delimiter = options["delimiter"] || ","

        begin
          parts = number_with_precision(number, precision).split('.')
          unit + number_with_delimiter(parts[0], delimiter) + separator + parts[1].to_s
        rescue
          number
        end
      end

      # Formats a +number+ as a percentage string (e.g., 65%). You can customize the
      # format in the +options+ hash.
      #
      # ==== Options
      # * <tt>:precision</tt>  - Sets the level of precision (defaults to 3).
      # * <tt>:separator</tt>  - Sets the separator between the units (defaults to ".").
      #
      # ==== Examples
      #  number_to_percentage(100)                         # => 100.000%
      #  number_to_percentage(100, :precision => 0)        # => 100%
      #
      #  number_to_percentage(302.24398923423, :precision => 5)
      #  # => 302.24399%
      def number_to_percentage(number, options = {})
        options   = options.stringify_keys
        precision = options["precision"] || 3
        separator = options["separator"] || "."

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

      # Formats a +number+ with grouped thousands using +delimiter+ (e.g., 12,324). You
      # can customize the format using optional <em>delimiter</em> and <em>separator</em> parameters.
      #
      # ==== Options
      # * <tt>delimiter</tt>  - Sets the thousands delimiter (defaults to ",").
      # * <tt>separator</tt>  - Sets the separator between the units (defaults to ".").
      #
      # ==== Examples
      #  number_with_delimiter(12345678)       # => 12,345,678
      #  number_with_delimiter(12345678.05)    # => 12,345,678.05
      #  number_with_delimiter(12345678, ".")  # => 12.345.678
      #
      #  number_with_delimiter(98765432.98, " ", ",")
      #  # => 98 765 432,98
      def number_with_delimiter(number, delimiter=",", separator=".")
        begin
          parts = number.to_s.split('.')
          parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
          parts.join separator
        rescue
          number
        end
      end

      # Formats a +number+ with the specified level of +precision+ (e.g., 112.32 has a precision of 2). The default
      # level of precision is 3.
      #
      # ==== Examples
      #  number_with_precision(111.2345)     # => 111.235
      #  number_with_precision(111.2345, 2)  # => 111.24
      #  number_with_precision(13, 5)        # => 13.00000
      #  number_with_precision(389.32314, 0) # => 389
      def number_with_precision(number, precision=3)
        "%01.#{precision}f" % number
      rescue
        number
      end

      # Formats the bytes in +size+ into a more understandable representation
      # (e.g., giving it 1500 yields 1.5 KB). This method is useful for 
      # reporting file sizes to users. This method returns nil if
      # +size+ cannot be converted into a number. You can change the default
      # precision of 1 using the precision parameter +precision+.
      #
      # ==== Examples
      #  number_to_human_size(123)           # => 123 Bytes
      #  number_to_human_size(1234)          # => 1.2 KB
      #  number_to_human_size(12345)         # => 12.1 KB
      #  number_to_human_size(1234567)       # => 1.2 MB
      #  number_to_human_size(1234567890)    # => 1.1 GB
      #  number_to_human_size(1234567890123) # => 1.1 TB
      #  number_to_human_size(1234567, 2)    # => 1.18 MB
      #  number_to_human_size(483989, 0)     # => 4 MB
      def number_to_human_size(size, precision=1)
        size = Kernel.Float(size)
        case
          when size.to_i == 1;    "1 Byte"
          when size < 1.kilobyte; "%d Bytes" % size
          when size < 1.megabyte; "%.#{precision}f KB"  % (size / 1.0.kilobyte)
          when size < 1.gigabyte; "%.#{precision}f MB"  % (size / 1.0.megabyte)
          when size < 1.terabyte; "%.#{precision}f GB"  % (size / 1.0.gigabyte)
          else                    "%.#{precision}f TB"  % (size / 1.0.terabyte)
        end.sub(/([0-9])\.?0+ /, '\1 ' )
      rescue
        nil
      end
    end
  end
end
