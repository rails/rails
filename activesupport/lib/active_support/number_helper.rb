require 'active_support/core_ext/big_decimal/conversions'
require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/hash/keys'
require 'active_support/i18n'

module ActiveSupport
  module NumberHelper
    extend self

    DEFAULTS = {
      # Used in number_to_delimited
      # These are also the defaults for 'currency', 'percentage', 'precision', and 'human'
      format: {
        # Sets the separator between the units, for more precision (e.g. 1.0 / 2.0 == 0.5)
        separator: ".",
        # Delimits thousands (e.g. 1,000,000 is a million) (always in groups of three)
        delimiter: ",",
        # Number of decimals, behind the separator (the number 1 with a precision of 2 gives: 1.00)
        precision: 3,
        # If set to true, precision will mean the number of significant digits instead
        # of the number of decimal digits (1234 with precision 2 becomes 1200, 1.23543 becomes 1.2)
        significant: false,
        # If set, the zeros after the decimal separator will always be stripped (eg.: 1.200 will be 1.2)
        strip_insignificant_zeros: false
      },

      # Used in number_to_currency
      currency: {
        format: {
          format: "%u%n",
          negative_format: "-%u%n",
          unit: "$",
          # These five are to override number.format and are optional
          separator: ".",
          delimiter: ",",
          precision: 2,
          significant: false,
          strip_insignificant_zeros: false
        }
      },

      # Used in number_to_percentage
      percentage: {
        format: {
          delimiter: "",
          format: "%n%"
        }
      },

      # Used in number_to_rounded
      precision: {
        format: {
          delimiter: ""
        }
      },

      # Used in number_to_human_size and number_to_human
      human: {
        format: {
          # These five are to override number.format and are optional
          delimiter: "",
          precision: 3,
          significant: true,
          strip_insignificant_zeros: true
        },
        # Used in number_to_human_size
        storage_units: {
          # Storage units output formatting.
          # %u is the storage unit, %n is the number (default: 2 MB)
          format: "%n %u",
          units: {
            byte: "Bytes",
            kb: "KB",
            mb: "MB",
            gb: "GB",
            tb: "TB"
          }
        },
        # Used in number_to_human
        decimal_units: {
          format: "%n %u",
          # Decimal units output formatting
          # By default we will only quantify some of the exponents
          # but the commented ones might be defined or overridden
          # by the user.
          units: {
            # femto: Quadrillionth
            # pico: Trillionth
            # nano: Billionth
            # micro: Millionth
            # mili: Thousandth
            # centi: Hundredth
            # deci: Tenth
            unit: "",
            # ten:
            #   one: Ten
            #   other: Tens
            # hundred: Hundred
            thousand: "Thousand",
            million: "Million",
            billion: "Billion",
            trillion: "Trillion",
            quadrillion: "Quadrillion"
          }
        }
      }
    }

    DECIMAL_UNITS = { 0 => :unit, 1 => :ten, 2 => :hundred, 3 => :thousand, 6 => :million, 9 => :billion, 12 => :trillion, 15 => :quadrillion,
      -1 => :deci, -2 => :centi, -3 => :mili, -6 => :micro, -9 => :nano, -12 => :pico, -15 => :femto }

    STORAGE_UNITS = [:byte, :kb, :mb, :gb, :tb]

    # Formats a +number+ into a US phone number (e.g., (555)
    # 123-9876). You can customize the format in the +options+ hash.
    #
    # ==== Options
    #
    # * <tt>:area_code</tt> - Adds parentheses around the area code.
    # * <tt>:delimiter</tt> - Specifies the delimiter to use
    #   (defaults to "-").
    # * <tt>:extension</tt> - Specifies an extension to add to the
    #   end of the generated number.
    # * <tt>:country_code</tt> - Sets the country code for the phone
    #   number.
    # ==== Examples
    #
    #   number_to_phone(5551234)                                     # => 555-1234
    #   number_to_phone("5551234")                                   # => 555-1234
    #   number_to_phone(1235551234)                                  # => 123-555-1234
    #   number_to_phone(1235551234, area_code: true)                 # => (123) 555-1234
    #   number_to_phone(1235551234, delimiter: ' ')                  # => 123 555 1234
    #   number_to_phone(1235551234, area_code: true, extension: 555) # => (123) 555-1234 x 555
    #   number_to_phone(1235551234, country_code: 1)                 # => +1-123-555-1234
    #   number_to_phone("123a456")                                   # => 123a456
    #
    #   number_to_phone(1235551234, country_code: 1, extension: 1343, delimiter: '.')
    #   # => +1.123.555.1234 x 1343
    def number_to_phone(number, options = {})
      return unless number
      options = options.symbolize_keys

      number       = number.to_s.strip
      area_code    = options[:area_code]
      delimiter    = options[:delimiter] || "-"
      extension    = options[:extension]
      country_code = options[:country_code]

      if area_code
        number.gsub!(/(\d{1,3})(\d{3})(\d{4}$)/,"(\\1) \\2#{delimiter}\\3")
      else
        number.gsub!(/(\d{0,3})(\d{3})(\d{4})$/,"\\1#{delimiter}\\2#{delimiter}\\3")
        number.slice!(0, 1) if number.start_with?(delimiter) && !delimiter.blank?
      end

      str = ''
      str << "+#{country_code}#{delimiter}" unless country_code.blank?
      str << number
      str << " x #{extension}" unless extension.blank?
      str
    end

    # Formats a +number+ into a currency string (e.g., $13.65). You
    # can customize the format in the +options+ hash.
    #
    # ==== Options
    #
    # * <tt>:locale</tt> - Sets the locale to be used for formatting
    #   (defaults to current locale).
    # * <tt>:precision</tt> - Sets the level of precision (defaults
    #   to 2).
    # * <tt>:unit</tt> - Sets the denomination of the currency
    #   (defaults to "$").
    # * <tt>:separator</tt> - Sets the separator between the units
    #   (defaults to ".").
    # * <tt>:delimiter</tt> - Sets the thousands delimiter (defaults
    #   to ",").
    # * <tt>:format</tt> - Sets the format for non-negative numbers
    #   (defaults to "%u%n").  Fields are <tt>%u</tt> for the
    #   currency, and <tt>%n</tt> for the number.
    # * <tt>:negative_format</tt> - Sets the format for negative
    #   numbers (defaults to prepending an hyphen to the formatted
    #   number given by <tt>:format</tt>).  Accepts the same fields
    #   than <tt>:format</tt>, except <tt>%n</tt> is here the
    #   absolute value of the number.
    #
    # ==== Examples
    #
    #   number_to_currency(1234567890.50)                # => $1,234,567,890.50
    #   number_to_currency(1234567890.506)               # => $1,234,567,890.51
    #   number_to_currency(1234567890.506, precision: 3) # => $1,234,567,890.506
    #   number_to_currency(1234567890.506, locale: :fr)  # => 1 234 567 890,51 €
    #   number_to_currency('123a456')                    # => $123a456
    #
    #   number_to_currency(-1234567890.50, negative_format: '(%u%n)')
    #   # => ($1,234,567,890.50)
    #   number_to_currency(1234567890.50, unit: '&pound;', separator: ',', delimiter: '')
    #   # => &pound;1234567890,50
    #   number_to_currency(1234567890.50, unit: '&pound;', separator: ',', delimiter: '', format: '%n %u')
    #   # => 1234567890,50 &pound;
    def number_to_currency(number, options = {})
      return unless number
      options = options.symbolize_keys

      currency = i18n_format_options(options[:locale], :currency)
      currency[:negative_format] ||= "-" + currency[:format] if currency[:format]

      defaults  = default_format_options(:currency).merge!(currency)
      defaults[:negative_format] = "-" + options[:format] if options[:format]
      options   = defaults.merge!(options)

      unit      = options.delete(:unit)
      format    = options.delete(:format)

      if number.to_f.phase != 0
        format = options.delete(:negative_format)
        number = number.respond_to?("abs") ? number.abs : number.sub(/^-/, '')
      end

      format.gsub('%n', self.number_to_rounded(number, options)).gsub('%u', unit)
    end

    # Formats a +number+ as a percentage string (e.g., 65%). You can
    # customize the format in the +options+ hash.
    #
    # ==== Options
    #
    # * <tt>:locale</tt> - Sets the locale to be used for formatting
    #   (defaults to current locale).
    # * <tt>:precision</tt> - Sets the precision of the number
    #   (defaults to 3).
    # * <tt>:significant</tt> - If +true+, precision will be the #
    #   of significant_digits. If +false+, the # of fractional
    #   digits (defaults to +false+).
    # * <tt>:separator</tt> - Sets the separator between the
    #   fractional and integer digits (defaults to ".").
    # * <tt>:delimiter</tt> - Sets the thousands delimiter (defaults
    #   to "").
    # * <tt>:strip_insignificant_zeros</tt> - If +true+ removes
    #   insignificant zeros after the decimal separator (defaults to
    #   +false+).
    # * <tt>:format</tt> - Specifies the format of the percentage
    #   string The number field is <tt>%n</tt> (defaults to "%n%").
    #
    # ==== Examples
    #
    #   number_to_percentage(100)                                 # => 100.000%
    #   number_to_percentage('98')                                # => 98.000%
    #   number_to_percentage(100, precision: 0)                   # => 100%
    #   number_to_percentage(1000, delimiter: '.', separator: ,') # => 1.000,000%
    #   number_to_percentage(302.24398923423, precision: 5)       # => 302.24399%
    #   number_to_percentage(1000, :locale => :fr)                # => 1 000,000%
    #   number_to_percentage('98a')                               # => 98a%
    #   number_to_percentage(100, format: '%n  %')                # => 100  %
    def number_to_percentage(number, options = {})
      return unless number
      options = options.symbolize_keys

      defaults = format_options(options[:locale], :percentage)
      options  = defaults.merge!(options)

      format = options[:format] || "%n%"
      format.gsub('%n', self.number_to_rounded(number, options))
    end

    # Formats a +number+ with grouped thousands using +delimiter+
    # (e.g., 12,324). You can customize the format in the +options+
    # hash.
    #
    # ==== Options
    #
    # * <tt>:locale</tt> - Sets the locale to be used for formatting
    #   (defaults to current locale).
    # * <tt>:delimiter</tt> - Sets the thousands delimiter (defaults
    #   to ",").
    # * <tt>:separator</tt> - Sets the separator between the
    #   fractional and integer digits (defaults to ".").
    #
    # ==== Examples
    #
    #   number_to_delimited(12345678)                    # => 12,345,678
    #   number_to_delimited('123456')                    # => 123,456
    #   number_to_delimited(12345678.05)                 # => 12,345,678.05
    #   number_to_delimited(12345678, delimiter: '.')    # => 12.345.678
    #   number_to_delimited(12345678, delimiter: ',')    # => 12,345,678
    #   number_to_delimited(12345678.05, separator: ' ') # => 12,345,678 05
    #   number_to_delimited(12345678.05, locale: :fr)    # => 12 345 678,05
    #   number_to_delimited('112a')                      # => 112a
    #   number_to_delimited(98765432.98, delimiter: ' ', separator: ',')
    #   # => 98 765 432,98
    def number_to_delimited(number, options = {})
      options = options.symbolize_keys

      return number unless valid_float?(number)

      options = format_options(options[:locale]).merge!(options)

      parts = number.to_s.to_str.split('.')
      parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{options[:delimiter]}")
      parts.join(options[:separator])
    end

    # Formats a +number+ with the specified level of
    # <tt>:precision</tt> (e.g., 112.32 has a precision of 2 if
    # +:significant+ is +false+, and 5 if +:significant+ is +true+).
    # You can customize the format in the +options+ hash.
    #
    # ==== Options
    #
    # * <tt>:locale</tt> - Sets the locale to be used for formatting
    #   (defaults to current locale).
    # * <tt>:precision</tt> - Sets the precision of the number
    #   (defaults to 3).
    # * <tt>:significant</tt> - If +true+, precision will be the #
    #   of significant_digits. If +false+, the # of fractional
    #   digits (defaults to +false+).
    # * <tt>:separator</tt> - Sets the separator between the
    #   fractional and integer digits (defaults to ".").
    # * <tt>:delimiter</tt> - Sets the thousands delimiter (defaults
    #   to "").
    # * <tt>:strip_insignificant_zeros</tt> - If +true+ removes
    #   insignificant zeros after the decimal separator (defaults to
    #   +false+).
    #
    # ==== Examples
    #
    #   number_to_rounded(111.2345)                                  # => 111.235
    #   number_to_rounded(111.2345, precision: 2)                    # => 111.23
    #   number_to_rounded(13, precision: 5)                          # => 13.00000
    #   number_to_rounded(389.32314, precision: 0)                   # => 389
    #   number_to_rounded(111.2345, significant: true)               # => 111
    #   number_to_rounded(111.2345, precision: 1, significant: true) # => 100
    #   number_to_rounded(13, precision: 5, significant: true)       # => 13.000
    #   number_to_rounded(111.234, locale: :fr)                      # => 111,234
    #
    #   number_to_rounded(13, precision: 5, significant: true, strip_insignificant_zeros: true)
    #   # => 13
    #
    #   number_to_rounded(389.32314, precision: 4, significant: true) # => 389.3
    #   number_to_rounded(1111.2345, precision: 2, separator: ',', delimiter: '.')
    #   # => 1.111,23
    def number_to_rounded(number, options = {})
      return number unless valid_float?(number)
      number  = Float(number)
      options = options.symbolize_keys

      defaults = format_options(options[:locale], :precision)
      options  = defaults.merge!(options)

      precision = options.delete :precision
      significant = options.delete :significant
      strip_insignificant_zeros = options.delete :strip_insignificant_zeros

      if significant && precision > 0
        if number == 0
          digits, rounded_number = 1, 0
        else
          digits = (Math.log10(number.abs) + 1).floor
          rounded_number = (BigDecimal.new(number.to_s) / BigDecimal.new((10 ** (digits - precision)).to_f.to_s)).round.to_f * 10 ** (digits - precision)
          digits = (Math.log10(rounded_number.abs) + 1).floor # After rounding, the number of digits may have changed
        end
        precision -= digits
        precision = 0 if precision < 0 # don't let it be negative
      else
        rounded_number = BigDecimal.new(number.to_s).round(precision).to_f
        rounded_number = rounded_number.abs if rounded_number.zero? # prevent showing negative zeros
      end
      formatted_number = self.number_to_delimited("%01.#{precision}f" % rounded_number, options)
      if strip_insignificant_zeros
        escaped_separator = Regexp.escape(options[:separator])
        formatted_number.sub(/(#{escaped_separator})(\d*[1-9])?0+\z/, '\1\2').sub(/#{escaped_separator}\z/, '')
      else
        formatted_number
      end
    end

    # Formats the bytes in +number+ into a more understandable
    # representation (e.g., giving it 1500 yields 1.5 KB). This
    # method is useful for reporting file sizes to users. You can
    # customize the format in the +options+ hash.
    #
    # See <tt>number_to_human</tt> if you want to pretty-print a
    # generic number.
    #
    # ==== Options
    #
    # * <tt>:locale</tt> - Sets the locale to be used for formatting
    #   (defaults to current locale).
    # * <tt>:precision</tt> - Sets the precision of the number
    #   (defaults to 3).
    # * <tt>:significant</tt> - If +true+, precision will be the #
    #   of significant_digits. If +false+, the # of fractional
    #   digits (defaults to +true+)
    # * <tt>:separator</tt> - Sets the separator between the
    #   fractional and integer digits (defaults to ".").
    # * <tt>:delimiter</tt> - Sets the thousands delimiter (defaults
    #   to "").
    # * <tt>:strip_insignificant_zeros</tt> - If +true+ removes
    #   insignificant zeros after the decimal separator (defaults to
    #   +true+)
    # * <tt>:prefix</tt> - If +:si+ formats the number using the SI
    #   prefix (defaults to :binary)
    #
    # ==== Examples
    #
    #   number_to_human_size(123)                                    # => 123 Bytes
    #   number_to_human_size(1234)                                   # => 1.21 KB
    #   number_to_human_size(12345)                                  # => 12.1 KB
    #   number_to_human_size(1234567)                                # => 1.18 MB
    #   number_to_human_size(1234567890)                             # => 1.15 GB
    #   number_to_human_size(1234567890123)                          # => 1.12 TB
    #   number_to_human_size(1234567, precision: 2)                  # => 1.2 MB
    #   number_to_human_size(483989, precision: 2)                   # => 470 KB
    #   number_to_human_size(1234567, precision: 2, separator: ',')  # => 1,2 MB
    #
    # Non-significant zeros after the fractional separator are stripped out by
    # default (set <tt>:strip_insignificant_zeros</tt> to +false+ to change that):
    #
    #   number_to_human_size(1234567890123, precision: 5) # => "1.1229 TB"
    #   number_to_human_size(524288000, precision: 5)     # => "500 MB"
    def number_to_human_size(number, options = {})
      options = options.symbolize_keys

      return number unless valid_float?(number)
      number = Float(number)

      defaults = format_options(options[:locale], :human)
      options  = defaults.merge!(options)

      #for backwards compatibility with those that didn't add strip_insignificant_zeros to their locale files
      options[:strip_insignificant_zeros] = true if not options.key?(:strip_insignificant_zeros)

      storage_units_format = translate_number_value_with_default('human.storage_units.format', :locale => options[:locale], :raise => true)

      base = options[:prefix] == :si ? 1000 : 1024

      if number.to_i < base
        unit = translate_number_value_with_default('human.storage_units.units.byte', :locale => options[:locale], :count => number.to_i, :raise => true)
        storage_units_format.gsub(/%n/, number.to_i.to_s).gsub(/%u/, unit)
      else
        max_exp  = STORAGE_UNITS.size - 1
        exponent = (Math.log(number) / Math.log(base)).to_i # Convert to base
        exponent = max_exp if exponent > max_exp # we need this to avoid overflow for the highest unit
        number  /= base ** exponent

        unit_key = STORAGE_UNITS[exponent]
        unit = translate_number_value_with_default("human.storage_units.units.#{unit_key}", :locale => options[:locale], :count => number, :raise => true)

        formatted_number = self.number_to_rounded(number, options)
        storage_units_format.gsub(/%n/, formatted_number).gsub(/%u/, unit)
      end
    end

    # Pretty prints (formats and approximates) a number in a way it
    # is more readable by humans (eg.: 1200000000 becomes "1.2
    # Billion"). This is useful for numbers that can get very large
    # (and too hard to read).
    #
    # See <tt>number_to_human_size</tt> if you want to print a file
    # size.
    #
    # You can also define you own unit-quantifier names if you want
    # to use other decimal units (eg.: 1500 becomes "1.5
    # kilometers", 0.150 becomes "150 milliliters", etc). You may
    # define a wide range of unit quantifiers, even fractional ones
    # (centi, deci, mili, etc).
    #
    # ==== Options
    #
    # * <tt>:locale</tt> - Sets the locale to be used for formatting
    #   (defaults to current locale).
    # * <tt>:precision</tt> - Sets the precision of the number
    #   (defaults to 3).
    # * <tt>:significant</tt> - If +true+, precision will be the #
    #   of significant_digits. If +false+, the # of fractional
    #   digits (defaults to +true+)
    # * <tt>:separator</tt> - Sets the separator between the
    #   fractional and integer digits (defaults to ".").
    # * <tt>:delimiter</tt> - Sets the thousands delimiter (defaults
    #   to "").
    # * <tt>:strip_insignificant_zeros</tt> - If +true+ removes
    #   insignificant zeros after the decimal separator (defaults to
    #   +true+)
    # * <tt>:units</tt> - A Hash of unit quantifier names. Or a
    #   string containing an i18n scope where to find this hash. It
    #   might have the following keys:
    #   * *integers*: <tt>:unit</tt>, <tt>:ten</tt>,
    #     *<tt>:hundred</tt>, <tt>:thousand</tt>, <tt>:million</tt>,
    #     *<tt>:billion</tt>, <tt>:trillion</tt>,
    #     *<tt>:quadrillion</tt>
    #   * *fractionals*: <tt>:deci</tt>, <tt>:centi</tt>,
    #     *<tt>:mili</tt>, <tt>:micro</tt>, <tt>:nano</tt>,
    #     *<tt>:pico</tt>, <tt>:femto</tt>
    # * <tt>:format</tt> - Sets the format of the output string
    #   (defaults to "%n %u"). The field types are:
    #   * %u - The quantifier (ex.: 'thousand')
    #   * %n - The number
    #
    # ==== Examples
    #
    #   number_to_human(123)                         # => "123"
    #   number_to_human(1234)                        # => "1.23 Thousand"
    #   number_to_human(12345)                       # => "12.3 Thousand"
    #   number_to_human(1234567)                     # => "1.23 Million"
    #   number_to_human(1234567890)                  # => "1.23 Billion"
    #   number_to_human(1234567890123)               # => "1.23 Trillion"
    #   number_to_human(1234567890123456)            # => "1.23 Quadrillion"
    #   number_to_human(1234567890123456789)         # => "1230 Quadrillion"
    #   number_to_human(489939, precision: 2)        # => "490 Thousand"
    #   number_to_human(489939, precision: 4)        # => "489.9 Thousand"
    #   number_to_human(1234567, precision: 4,
    #                            significant: false) # => "1.2346 Million"
    #   number_to_human(1234567, precision: 1,
    #                            separator: ',',
    #                            significant: false) # => "1,2 Million"
    #
    # Non-significant zeros after the decimal separator are stripped
    # out by default (set <tt>:strip_insignificant_zeros</tt> to
    # +false+ to change that):
    #
    #   number_to_human(12345012345, significant_digits: 6) # => "12.345 Billion"
    #   number_to_human(500000000, precision: 5)            # => "500 Million"
    #
    # ==== Custom Unit Quantifiers
    #
    # You can also use your own custom unit quantifiers:
    #  number_to_human(500000, :units => {:unit => "ml", :thousand => "lt"})  # => "500 lt"
    #
    # If in your I18n locale you have:
    #
    #   distance:
    #     centi:
    #       one: "centimeter"
    #       other: "centimeters"
    #     unit:
    #       one: "meter"
    #       other: "meters"
    #     thousand:
    #       one: "kilometer"
    #       other: "kilometers"
    #     billion: "gazillion-distance"
    #
    # Then you could do:
    #
    #   number_to_human(543934, :units => :distance)               # => "544 kilometers"
    #   number_to_human(54393498, :units => :distance)             # => "54400 kilometers"
    #   number_to_human(54393498000, :units => :distance)          # => "54.4 gazillion-distance"
    #   number_to_human(343, :units => :distance, :precision => 1) # => "300 meters"
    #   number_to_human(1, :units => :distance)                    # => "1 meter"
    #   number_to_human(0.34, :units => :distance)                 # => "34 centimeters"
    def number_to_human(number, options = {})
      options = options.symbolize_keys

      return number unless valid_float?(number)
      number = Float(number)

      defaults = format_options(options[:locale], :human)
      options  = defaults.merge!(options)

      #for backwards compatibility with those that didn't add strip_insignificant_zeros to their locale files
      options[:strip_insignificant_zeros] = true if not options.key?(:strip_insignificant_zeros)

      inverted_du = DECIMAL_UNITS.invert

      units = options.delete :units
      unit_exponents = case units
      when Hash
        units
      when String, Symbol
        I18n.translate(:"#{units}", :locale => options[:locale], :raise => true)
      when nil
        translate_number_value_with_default("human.decimal_units.units", :locale => options[:locale], :raise => true)
      else
        raise ArgumentError, ":units must be a Hash or String translation scope."
      end.keys.map{|e_name| inverted_du[e_name] }.sort_by{|e| -e}

      number_exponent = number != 0 ? Math.log10(number.abs).floor : 0
      display_exponent = unit_exponents.find{ |e| number_exponent >= e } || 0
      number  /= 10 ** display_exponent

      unit = case units
      when Hash
        units[DECIMAL_UNITS[display_exponent]]
      when String, Symbol
        I18n.translate(:"#{units}.#{DECIMAL_UNITS[display_exponent]}", :locale => options[:locale], :count => number.to_i)
      else
        translate_number_value_with_default("human.decimal_units.units.#{DECIMAL_UNITS[display_exponent]}", :locale => options[:locale], :count => number.to_i)
      end

      decimal_format = options[:format] || translate_number_value_with_default('human.decimal_units.format', :locale => options[:locale])
      formatted_number = self.number_to_rounded(number, options)
      decimal_format.gsub(/%n/, formatted_number).gsub(/%u/, unit).strip
    end

    def self.private_module_and_instance_method(method_name) #:nodoc:
      private method_name
      private_class_method method_name
    end
    private_class_method :private_module_and_instance_method

    def format_options(locale, namespace = nil) #:nodoc:
      default_format_options(namespace).merge!(i18n_format_options(locale, namespace))
    end
    private_module_and_instance_method :format_options

    def default_format_options(namespace = nil) #:nodoc:
      options = DEFAULTS[:format].dup
      options.merge!(DEFAULTS[namespace][:format]) if namespace
      options
    end
    private_module_and_instance_method :default_format_options

    def i18n_format_options(locale, namespace = nil) #:nodoc:
      options = I18n.translate(:'number.format', locale: locale, default: {}).dup
      if namespace
        options.merge!(I18n.translate(:"number.#{namespace}.format", locale: locale, default: {}))
      end
      options
    end
    private_module_and_instance_method :i18n_format_options

    def translate_number_value_with_default(key, i18n_options = {}) #:nodoc:
      default = key.split('.').reduce(DEFAULTS) { |defaults, k| defaults[k.to_sym] }

      I18n.translate(key, { default: default, scope: :number }.merge!(i18n_options))
    end
    private_module_and_instance_method :translate_number_value_with_default

    def valid_float?(number) #:nodoc:
      Float(number)
    rescue ArgumentError, TypeError
      false
    end
    private_module_and_instance_method :valid_float?
  end
end
