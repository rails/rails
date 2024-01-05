# frozen_string_literal: true

module ActiveSupport
  module NumberHelper
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :NumberConverter
      autoload :RoundingHelper
      autoload :NumberToRoundedConverter
      autoload :NumberToDelimitedConverter
      autoload :NumberToHumanConverter
      autoload :NumberToHumanSizeConverter
      autoload :NumberToPhoneConverter
      autoload :NumberToCurrencyConverter
      autoload :NumberToPercentageConverter
    end

    extend self

    # Formats +number+ into a phone number.
    #
    #   number_to_phone(5551234)    # => "555-1234"
    #   number_to_phone("5551234")  # => "555-1234"
    #   number_to_phone(1235551234) # => "123-555-1234"
    #   number_to_phone("12x34")    # => "12x34"
    #
    #   number_to_phone(1235551234, delimiter: ".", country_code: 1, extension: 1343)
    #   # => "+1.123.555.1234 x 1343"
    #
    # ==== Options
    #
    # [+:area_code+]
    #   Whether to use parentheses for the area code. Defaults to false.
    #
    #     number_to_phone(1235551234, area_code: true)
    #     # => "(123) 555-1234"
    #
    # [+:delimiter+]
    #   The digit group delimiter to use. Defaults to <tt>"-"</tt>.
    #
    #     number_to_phone(1235551234, delimiter: " ")
    #     # => "123 555 1234"
    #
    # [+:country_code+]
    #   A country code to prepend.
    #
    #     number_to_phone(1235551234, country_code: 1)
    #     # => "+1-123-555-1234"
    #
    # [+:extension+]
    #   An extension to append.
    #
    #     number_to_phone(1235551234, extension: 555)
    #     # => "123-555-1234 x 555"
    #
    # [+:pattern+]
    #   A regexp that specifies how the digits should be grouped. The first
    #   three captures from the regexp are treated as digit groups.
    #
    #     number_to_phone(13312345678, pattern: /(\d{3})(\d{4})(\d{4})$/)
    #     # => "133-1234-5678"
    #     number_to_phone(75561234567, pattern: /(\d{1,4})(\d{4})(\d{4})$/, area_code: true)
    #     # => "(755) 6123-4567"
    #
    def number_to_phone(number, options = {})
      NumberToPhoneConverter.convert(number, options)
    end

    # Formats a +number+ into a currency string.
    #
    #   number_to_currency(1234567890.50)  # => "$1,234,567,890.50"
    #   number_to_currency(1234567890.506) # => "$1,234,567,890.51"
    #   number_to_currency("12x34")        # => "$12x34"
    #
    #   number_to_currency(1234567890.50, unit: "&pound;", separator: ",", delimiter: "")
    #   # => "&pound;1234567890,50"
    #
    # The currency unit and number formatting of the current locale will be used
    # unless otherwise specified via options. No currency conversion is
    # performed. If the user is given a way to change their locale, they will
    # also be able to change the relative value of the currency displayed with
    # this helper. If your application will ever support multiple locales, you
    # may want to specify a constant +:locale+ option or consider using a
    # library capable of currency conversion.
    #
    # ==== Options
    #
    # [+:locale+]
    #   The locale to use for formatting. Defaults to the current locale.
    #
    #     number_to_currency(1234567890.506, locale: :fr)
    #     # => "1 234 567 890,51 €"
    #
    # [+:precision+]
    #   The level of precision. Defaults to 2.
    #
    #     number_to_currency(1234567890.123, precision: 3) # => "$1,234,567,890.123"
    #     number_to_currency(0.456789, precision: 0)       # => "$0"
    #
    # [+:round_mode+]
    #   Specifies how rounding is performed. See +BigDecimal.mode+. Defaults to
    #   +:default+.
    #
    #     number_to_currency(1234567890.01, precision: 0, round_mode: :up)
    #     # => "$1,234,567,891"
    #
    # [+:unit+]
    #   The denomination of the currency. Defaults to <tt>"$"</tt>.
    #
    # [+:separator+]
    #   The decimal separator. Defaults to <tt>"."</tt>.
    #
    # [+:delimiter+]
    #   The thousands delimiter. Defaults to <tt>","</tt>.
    #
    # [+:format+]
    #   The format for non-negative numbers. <tt>%u</tt> represents the currency,
    #   and <tt>%n</tt> represents the number. Defaults to <tt>"%u%n"</tt>.
    #
    #     number_to_currency(1234567890.50, format: "%n %u")
    #     # => "1,234,567,890.50 $"
    #
    # [+:negative_format+]
    #   The format for negative numbers. <tt>%u</tt> and <tt>%n</tt> behave the
    #   same as in +:format+, but <tt>%n</tt> represents the absolute value of
    #   the number. Defaults to the value of +:format+ prepended with <tt>-</tt>.
    #
    #     number_to_currency(-1234567890.50, negative_format: "(%u%n)")
    #     # => "($1,234,567,890.50)"
    #
    # [+:strip_insignificant_zeros+]
    #   Whether to remove insignificant zeros after the decimal separator.
    #   Defaults to false.
    #
    #     number_to_currency(1234567890.50, strip_insignificant_zeros: true)
    #     # => "$1,234,567,890.5"
    #
    def number_to_currency(number, options = {})
      NumberToCurrencyConverter.convert(number, options)
    end

    # Formats +number+ as a percentage string.
    #
    #   number_to_percentage(100)   # => "100.000%"
    #   number_to_percentage("99")  # => "99.000%"
    #   number_to_percentage("99x") # => "99x%"
    #
    #   number_to_percentage(12345.6789, delimiter: ".", separator: ",", precision: 2)
    #   # => "12.345,68%"
    #
    # ==== Options
    #
    # [+:locale+]
    #   The locale to use for formatting. Defaults to the current locale.
    #
    #     number_to_percentage(1000, locale: :fr)
    #     # => "1000,000%"
    #
    # [+:precision+]
    #   The level of precision, or +nil+ to preserve +number+'s precision.
    #   Defaults to 2.
    #
    #     number_to_percentage(12.3456789, precision: 4) # => "12.3457%"
    #     number_to_percentage(99.999, precision: 0)     # => "100%"
    #     number_to_percentage(99.999, precision: nil)   # => "99.999%"
    #
    # [+:round_mode+]
    #   Specifies how rounding is performed. See +BigDecimal.mode+. Defaults to
    #   +:default+.
    #
    #     number_to_percentage(12.3456789, precision: 4, round_mode: :down)
    #     # => "12.3456%"
    #
    # [+:significant+]
    #   Whether +:precision+ should be applied to significant digits instead of
    #   fractional digits. Defaults to false.
    #
    #     number_to_percentage(12345.6789)                                  # => "12345.679%"
    #     number_to_percentage(12345.6789, significant: true)               # => "12300%"
    #     number_to_percentage(12345.6789, precision: 2)                    # => "12345.68%"
    #     number_to_percentage(12345.6789, precision: 2, significant: true) # => "12000%"
    #
    # [+:separator+]
    #   The decimal separator. Defaults to <tt>"."</tt>.
    #
    # [+:delimiter+]
    #   The thousands delimiter. Defaults to <tt>","</tt>.
    #
    # [+:strip_insignificant_zeros+]
    #   Whether to remove insignificant zeros after the decimal separator.
    #   Defaults to false.
    #
    # [+:format+]
    #   The format of the output. <tt>%n</tt> represents the number. Defaults to
    #   <tt>"%n%"</tt>.
    #
    #     number_to_percentage(100, format: "%n  %")
    #     # => "100.000  %"
    #
    def number_to_percentage(number, options = {})
      NumberToPercentageConverter.convert(number, options)
    end

    # Formats +number+ by grouping thousands with a delimiter.
    #
    #   number_to_delimited(12345678)      # => "12,345,678"
    #   number_to_delimited("123456")      # => "123,456"
    #   number_to_delimited(12345678.9876) # => "12,345,678.9876"
    #   number_to_delimited("12x34")       # => "12x34"
    #
    #   number_to_delimited(12345678.9876, delimiter: ".", separator: ",")
    #   # => "12.345.678,9876"
    #
    # ==== Options
    #
    # [+:locale+]
    #   The locale to use for formatting. Defaults to the current locale.
    #
    #     number_to_delimited(12345678.05, locale: :fr)
    #     # => "12 345 678,05"
    #
    # [+:delimiter+]
    #   The thousands delimiter. Defaults to <tt>","</tt>.
    #
    #     number_to_delimited(12345678, delimiter: ".")
    #     # => "12.345.678"
    #
    # [+:separator+]
    #   The decimal separator. Defaults to <tt>"."</tt>.
    #
    #     number_to_delimited(12345678.05, separator: " ")
    #     # => "12,345,678 05"
    #
    # [+:delimiter_pattern+]
    #   A regexp to determine the placement of delimiters. Helpful when using
    #   currency formats like INR.
    #
    #     number_to_delimited("123456.78", delimiter_pattern: /(\d+?)(?=(\d\d)+(\d)(?!\d))/)
    #     # => "1,23,456.78"
    #
    def number_to_delimited(number, options = {})
      NumberToDelimitedConverter.convert(number, options)
    end

    # Formats +number+ to a specific level of precision.
    #
    #   number_to_rounded(12345.6789)                # => "12345.679"
    #   number_to_rounded(12345.6789, precision: 2)  # => "12345.68"
    #   number_to_rounded(12345.6789, precision: 0)  # => "12345"
    #   number_to_rounded(12345, precision: 5)       # => "12345.00000"
    #
    # ==== Options
    #
    # [+:locale+]
    #   The locale to use for formatting. Defaults to the current locale.
    #
    #     number_to_rounded(111.234, locale: :fr)
    #     # => "111,234"
    #
    # [+:precision+]
    #   The level of precision, or +nil+ to preserve +number+'s precision.
    #   Defaults to 3.
    #
    #     number_to_rounded(12345.6789, precision: nil)
    #     # => "12345.6789"
    #
    # [+:round_mode+]
    #   Specifies how rounding is performed. See +BigDecimal.mode+. Defaults to
    #   +:default+.
    #
    #     number_to_rounded(12.34, precision: 0, round_mode: :up)
    #     # => "13"
    #
    # [+:significant+]
    #   Whether +:precision+ should be applied to significant digits instead of
    #   fractional digits. Defaults to false.
    #
    #     number_to_rounded(12345.6789)                                  # => "12345.679"
    #     number_to_rounded(12345.6789, significant: true)               # => "12300"
    #     number_to_rounded(12345.6789, precision: 2)                    # => "12345.68"
    #     number_to_rounded(12345.6789, precision: 2, significant: true) # => "12000"
    #
    # [+:separator+]
    #   The decimal separator. Defaults to <tt>"."</tt>.
    #
    # [+:delimiter+]
    #   The thousands delimiter. Defaults to <tt>","</tt>.
    #
    # [+:strip_insignificant_zeros+]
    #   Whether to remove insignificant zeros after the decimal separator.
    #   Defaults to false.
    #
    #     number_to_rounded(12.34, strip_insignificant_zeros: false)  # => "12.340"
    #     number_to_rounded(12.34, strip_insignificant_zeros: true)   # => "12.34"
    #     number_to_rounded(12.3456, strip_insignificant_zeros: true) # => "12.346"
    #
    def number_to_rounded(number, options = {})
      NumberToRoundedConverter.convert(number, options)
    end

    # Formats +number+ as bytes into a more human-friendly representation.
    # Useful for reporting file sizes to users.
    #
    #   number_to_human_size(123)                 # => "123 Bytes"
    #   number_to_human_size(1234)                # => "1.21 KB"
    #   number_to_human_size(12345)               # => "12.1 KB"
    #   number_to_human_size(1234567)             # => "1.18 MB"
    #   number_to_human_size(1234567890)          # => "1.15 GB"
    #   number_to_human_size(1234567890123)       # => "1.12 TB"
    #   number_to_human_size(1234567890123456)    # => "1.1 PB"
    #   number_to_human_size(1234567890123456789) # => "1.07 EB"
    #
    # See #number_to_human if you want to pretty-print a generic number.
    #
    # ==== Options
    #
    # [+:locale+]
    #   The locale to use for formatting. Defaults to the current locale.
    #
    # [+:precision+]
    #   The level of precision. Defaults to 3.
    #
    #     number_to_human_size(123456, precision: 2)  # => "120 KB"
    #     number_to_human_size(1234567, precision: 2) # => "1.2 MB"
    #
    # [+:round_mode+]
    #   Specifies how rounding is performed. See +BigDecimal.mode+. Defaults to
    #   +:default+.
    #
    #     number_to_human_size(123456, precision: 2, round_mode: :up)
    #     # => "130 KB"
    #
    # [+:significant+]
    #   Whether +:precision+ should be applied to significant digits instead of
    #   fractional digits. Defaults to true.
    #
    # [+:separator+]
    #   The decimal separator. Defaults to <tt>"."</tt>.
    #
    #     number_to_human_size(1234567, separator: ",")
    #     # => "1,18 MB"
    #
    # [+:delimiter+]
    #   The thousands delimiter. Defaults to <tt>","</tt>.
    #
    # [+:strip_insignificant_zeros+]
    #   Whether to remove insignificant zeros after the decimal separator.
    #   Defaults to true.
    #
    def number_to_human_size(number, options = {})
      NumberToHumanSizeConverter.convert(number, options)
    end

    # Pretty prints (formats and approximates) a number in a way it
    # is more readable by humans (e.g.: 1200000000 becomes "1.2
    # Billion"). This is useful for numbers that can get very large
    # (and too hard to read).
    #
    # See <tt>number_to_human_size</tt> if you want to print a file
    # size.
    #
    # You can also define your own unit-quantifier names if you want
    # to use other decimal units (e.g.: 1500 becomes "1.5
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
    # * <tt>:round_mode</tt> - Determine how rounding is performed
    #   (defaults to :default. See BigDecimal::mode)
    # * <tt>:significant</tt> - If +true+, precision will be the number
    #   of significant_digits. If +false+, the number of fractional
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
    #     <tt>:hundred</tt>, <tt>:thousand</tt>, <tt>:million</tt>,
    #     <tt>:billion</tt>, <tt>:trillion</tt>,
    #     <tt>:quadrillion</tt>
    #   * *fractionals*: <tt>:deci</tt>, <tt>:centi</tt>,
    #     <tt>:mili</tt>, <tt>:micro</tt>, <tt>:nano</tt>,
    #     <tt>:pico</tt>, <tt>:femto</tt>
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
    #   number_to_human(489939, precision: 2
    #                         , round_mode: :down)   # => "480 Thousand"
    #   number_to_human(1234567, precision: 4,
    #                            significant: false) # => "1.2346 Million"
    #   number_to_human(1234567, precision: 1,
    #                            separator: ',',
    #                            significant: false) # => "1,2 Million"
    #
    #   number_to_human(500000000, precision: 5)           # => "500 Million"
    #   number_to_human(12345012345, significant: false)   # => "12.345 Billion"
    #
    # Non-significant zeros after the decimal separator are stripped
    # out by default (set <tt>:strip_insignificant_zeros</tt> to
    # +false+ to change that):
    #
    #   number_to_human(12.00001)                                       # => "12"
    #   number_to_human(12.00001, strip_insignificant_zeros: false)     # => "12.0"
    #
    # ==== Custom Unit Quantifiers
    #
    # You can also use your own custom unit quantifiers:
    #
    #   number_to_human(500000, units: { unit: 'ml', thousand: 'lt' })  # => "500 lt"
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
    #   number_to_human(543934, units: :distance)            # => "544 kilometers"
    #   number_to_human(54393498, units: :distance)          # => "54400 kilometers"
    #   number_to_human(54393498000, units: :distance)       # => "54.4 gazillion-distance"
    #   number_to_human(343, units: :distance, precision: 1) # => "300 meters"
    #   number_to_human(1, units: :distance)                 # => "1 meter"
    #   number_to_human(0.34, units: :distance)              # => "34 centimeters"
    def number_to_human(number, options = {})
      NumberToHumanConverter.convert(number, options)
    end
  end
end
