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
      #  number_to_phone(5551234)                                           # => 555-1234
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
        options      = options.symbolize_keys
        area_code    = options[:area_code] || nil
        delimiter    = options[:delimiter] || "-"
        extension    = options[:extension].to_s.strip || nil
        country_code = options[:country_code] || nil

        begin
          str = ""
          str << "+#{country_code}#{delimiter}" unless country_code.blank?
          str << if area_code
            number.gsub!(/([0-9]{1,3})([0-9]{3})([0-9]{4}$)/,"(\\1) \\2#{delimiter}\\3")
          else
            number.gsub!(/([0-9]{0,3})([0-9]{3})([0-9]{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
            number.starts_with?('-') ? number.slice!(1..-1) : number
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
      # * <tt>:unit</tt>       - Sets the denomination of the currency (defaults to "$").
      # * <tt>:separator</tt>  - Sets the separator between the units (defaults to ".").
      # * <tt>:delimiter</tt>  - Sets the thousands delimiter (defaults to ",").
      # * <tt>:format</tt>     - Sets the format of the output string (defaults to "%u%n"). The field types are:
      #
      #     %u  The currency unit
      #     %n  The number
      #
      # ==== Examples
      #  number_to_currency(1234567890.50)                    # => $1,234,567,890.50
      #  number_to_currency(1234567890.506)                   # => $1,234,567,890.51
      #  number_to_currency(1234567890.506, :precision => 3)  # => $1,234,567,890.506
      #
      #  number_to_currency(1234567890.50, :unit => "&pound;", :separator => ",", :delimiter => "")
      #  # => &pound;1234567890,50
      #  number_to_currency(1234567890.50, :unit => "&pound;", :separator => ",", :delimiter => "", :format => "%n %u")
      #  # => 1234567890,50 &pound;
      def number_to_currency(number, options = {})
        options.symbolize_keys!

        defaults  = I18n.translate(:'number.format', :locale => options[:locale], :raise => true) rescue {}
        currency  = I18n.translate(:'number.currency.format', :locale => options[:locale], :raise => true) rescue {}
        defaults  = defaults.merge(currency)

        precision = options[:precision] || defaults[:precision]
        unit      = options[:unit]      || defaults[:unit]
        separator = options[:separator] || defaults[:separator]
        delimiter = options[:delimiter] || defaults[:delimiter]
        format    = options[:format]    || defaults[:format]
        separator = '' if precision == 0

        begin
          format.gsub(/%n/, number_with_precision(number,
            :precision => precision,
            :delimiter => delimiter,
            :separator => separator)
          ).gsub(/%u/, unit)
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
      # * <tt>:delimiter</tt>  - Sets the thousands delimiter (defaults to "").
      #
      # ==== Examples
      #  number_to_percentage(100)                                        # => 100.000%
      #  number_to_percentage(100, :precision => 0)                       # => 100%
      #  number_to_percentage(1000, :delimiter => '.', :separator => ',') # => 1.000,000%
      #  number_to_percentage(302.24398923423, :precision => 5)           # => 302.24399%
      def number_to_percentage(number, options = {})
        options.symbolize_keys!

        defaults   = I18n.translate(:'number.format', :locale => options[:locale], :raise => true) rescue {}
        percentage = I18n.translate(:'number.percentage.format', :locale => options[:locale], :raise => true) rescue {}
        defaults  = defaults.merge(percentage)

        precision = options[:precision] || defaults[:precision]
        separator = options[:separator] || defaults[:separator]
        delimiter = options[:delimiter] || defaults[:delimiter]

        begin
          number_with_precision(number,
            :precision => precision,
            :separator => separator,
            :delimiter => delimiter) + "%"
        rescue
          number
        end
      end

      # Formats a +number+ with grouped thousands using +delimiter+ (e.g., 12,324). You can
      # customize the format in the +options+ hash.
      #
      # ==== Options
      # * <tt>:delimiter</tt>  - Sets the thousands delimiter (defaults to ",").
      # * <tt>:separator</tt>  - Sets the separator between the units (defaults to ".").
      #
      # ==== Examples
      #  number_with_delimiter(12345678)                        # => 12,345,678
      #  number_with_delimiter(12345678.05)                     # => 12,345,678.05
      #  number_with_delimiter(12345678, :delimiter => ".")     # => 12.345.678
      #  number_with_delimiter(12345678, :seperator => ",")     # => 12,345,678
      #  number_with_delimiter(98765432.98, :delimiter => " ", :separator => ",")
      #  # => 98 765 432,98
      #
      # You can still use <tt>number_with_delimiter</tt> with the old API that accepts the
      # +delimiter+ as its optional second and the +separator+ as its
      # optional third parameter:
      #  number_with_delimiter(12345678, " ")                     # => 12 345.678
      #  number_with_delimiter(12345678.05, ".", ",")             # => 12.345.678,05
      def number_with_delimiter(number, *args)
        options = args.extract_options!
        options.symbolize_keys!

        defaults = I18n.translate(:'number.format', :locale => options[:locale], :raise => true) rescue {}

        unless args.empty?
          ActiveSupport::Deprecation.warn('number_with_delimiter takes an option hash ' +
            'instead of separate delimiter and precision arguments.', caller)
          delimiter = args[0] || defaults[:delimiter]
          separator = args[1] || defaults[:separator]
        end

        delimiter ||= (options[:delimiter] || defaults[:delimiter])
        separator ||= (options[:separator] || defaults[:separator])

        begin
          parts = number.to_s.split('.')
          parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
          parts.join(separator)
        rescue
          number
        end
      end

      # Formats a +number+ with the specified level of <tt>:precision</tt> (e.g., 112.32 has a precision of 2).
      # You can customize the format in the +options+ hash.
      #
      # ==== Options
      # * <tt>:precision</tt>  - Sets the level of precision (defaults to 3).
      # * <tt>:separator</tt>  - Sets the separator between the units (defaults to ".").
      # * <tt>:delimiter</tt>  - Sets the thousands delimiter (defaults to "").
      #
      # ==== Examples
      #  number_with_precision(111.2345)                    # => 111.235
      #  number_with_precision(111.2345, :precision => 2)   # => 111.23
      #  number_with_precision(13, :precision => 5)         # => 13.00000
      #  number_with_precision(389.32314, :precision => 0)  # => 389
      #  number_with_precision(1111.2345, :precision => 2, :separator => ',', :delimiter => '.')
      #  # => 1.111,23
      #
      # You can still use <tt>number_with_precision</tt> with the old API that accepts the
      # +precision+ as its optional second parameter:
      #   number_with_precision(number_with_precision(111.2345, 2)   # => 111.23
      def number_with_precision(number, *args)
        options = args.extract_options!
        options.symbolize_keys!

        defaults           = I18n.translate(:'number.format', :locale => options[:locale], :raise => true) rescue {}
        precision_defaults = I18n.translate(:'number.precision.format', :locale => options[:locale],
                                                                        :raise => true) rescue {}
        defaults           = defaults.merge(precision_defaults)

        unless args.empty?
          ActiveSupport::Deprecation.warn('number_with_precision takes an option hash ' +
            'instead of a separate precision argument.', caller)
          precision = args[0] || defaults[:precision]
        end

        precision ||= (options[:precision] || defaults[:precision])
        separator ||= (options[:separator] || defaults[:separator])
        delimiter ||= (options[:delimiter] || defaults[:delimiter])

        begin
          rounded_number = (Float(number) * (10 ** precision)).round.to_f / 10 ** precision
          number_with_delimiter("%01.#{precision}f" % rounded_number,
            :separator => separator,
            :delimiter => delimiter)
        rescue
          number
        end
      end

      STORAGE_UNITS = [:byte, :kb, :mb, :gb, :tb].freeze

      # Formats the bytes in +size+ into a more understandable representation
      # (e.g., giving it 1500 yields 1.5 KB). This method is useful for
      # reporting file sizes to users. This method returns nil if
      # +size+ cannot be converted into a number. You can customize the
      # format in the +options+ hash.
      #
      # ==== Options
      # * <tt>:precision</tt>  - Sets the level of precision (defaults to 1).
      # * <tt>:separator</tt>  - Sets the separator between the units (defaults to ".").
      # * <tt>:delimiter</tt>  - Sets the thousands delimiter (defaults to "").
      #
      # ==== Examples
      #  number_to_human_size(123)                                          # => 123 Bytes
      #  number_to_human_size(1234)                                         # => 1.2 KB
      #  number_to_human_size(12345)                                        # => 12.1 KB
      #  number_to_human_size(1234567)                                      # => 1.2 MB
      #  number_to_human_size(1234567890)                                   # => 1.1 GB
      #  number_to_human_size(1234567890123)                                # => 1.1 TB
      #  number_to_human_size(1234567, :precision => 2)                     # => 1.18 MB
      #  number_to_human_size(483989, :precision => 0)                      # => 473 KB
      #  number_to_human_size(1234567, :precision => 2, :separator => ',')  # => 1,18 MB
      #
      # You can still use <tt>number_to_human_size</tt> with the old API that accepts the
      # +precision+ as its optional second parameter:
      #  number_to_human_size(1234567, 2)    # => 1.18 MB
      #  number_to_human_size(483989, 0)     # => 473 KB
      def number_to_human_size(number, *args)
        return nil if number.nil?

        options = args.extract_options!
        options.symbolize_keys!

        defaults = I18n.translate(:'number.format', :locale => options[:locale], :raise => true) rescue {}
        human    = I18n.translate(:'number.human.format', :locale => options[:locale], :raise => true) rescue {}
        defaults = defaults.merge(human)

        unless args.empty?
          ActiveSupport::Deprecation.warn('number_to_human_size takes an option hash ' +
            'instead of a separate precision argument.', caller)
          precision = args[0] || defaults[:precision]
        end

        precision ||= (options[:precision] || defaults[:precision])
        separator ||= (options[:separator] || defaults[:separator])
        delimiter ||= (options[:delimiter] || defaults[:delimiter])

        storage_units_format = I18n.translate(:'number.human.storage_units.format', :locale => options[:locale], :raise => true)

        if number.to_i < 1024
          unit = I18n.translate(:'number.human.storage_units.units.byte', :locale => options[:locale], :count => number.to_i, :raise => true)
          storage_units_format.gsub(/%n/, number.to_i.to_s).gsub(/%u/, unit)
        else
          max_exp  = STORAGE_UNITS.size - 1
          number   = Float(number)
          exponent = (Math.log(number) / Math.log(1024)).to_i # Convert to base 1024
          exponent = max_exp if exponent > max_exp # we need this to avoid overflow for the highest unit
          number  /= 1024 ** exponent

          unit_key = STORAGE_UNITS[exponent]
          unit = I18n.translate(:"number.human.storage_units.units.#{unit_key}", :locale => options[:locale], :count => number, :raise => true)

          begin
            escaped_separator = Regexp.escape(separator)
            formatted_number = number_with_precision(number,
              :precision => precision,
              :separator => separator,
              :delimiter => delimiter
            ).sub(/(\d)(#{escaped_separator}[1-9]*)?0+\z/, '\1\2').sub(/#{escaped_separator}\z/, '')
            storage_units_format.gsub(/%n/, formatted_number).gsub(/%u/, unit)
          rescue
            number
          end
        end
      end
    end
  end
end
