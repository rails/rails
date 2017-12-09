# frozen_string_literal: true

require "active_support/core_ext/big_decimal/conversions"
require "active_support/number_helper"
require "active_support/core_ext/module/deprecation"

module ActiveSupport::NumericWithFormat
  # Provides options for converting numbers into formatted strings.
  # Options are provided for phone numbers, currency, percentage,
  # precision, positional notation, file size and pretty printing.
  #
  # ==== Options
  #
  # For details on which formats use which options, see ActiveSupport::NumberHelper
  #
  # ==== Examples
  #
  #  Phone Numbers:
  #  5551234.to_s(:phone)                                     # => "555-1234"
  #  1235551234.to_s(:phone)                                  # => "123-555-1234"
  #  1235551234.to_s(:phone, area_code: true)                 # => "(123) 555-1234"
  #  1235551234.to_s(:phone, delimiter: ' ')                  # => "123 555 1234"
  #  1235551234.to_s(:phone, area_code: true, extension: 555) # => "(123) 555-1234 x 555"
  #  1235551234.to_s(:phone, country_code: 1)                 # => "+1-123-555-1234"
  #  1235551234.to_s(:phone, country_code: 1, extension: 1343, delimiter: '.')
  #  # => "+1.123.555.1234 x 1343"
  #
  #  Currency:
  #  1234567890.50.to_s(:currency)                 # => "$1,234,567,890.50"
  #  1234567890.506.to_s(:currency)                # => "$1,234,567,890.51"
  #  1234567890.506.to_s(:currency, precision: 3)  # => "$1,234,567,890.506"
  #  1234567890.506.to_s(:currency, locale: :fr)   # => "1 234 567 890,51 €"
  #  -1234567890.50.to_s(:currency, negative_format: '(%u%n)')
  #  # => "($1,234,567,890.50)"
  #  1234567890.50.to_s(:currency, unit: '&pound;', separator: ',', delimiter: '')
  #  # => "&pound;1234567890,50"
  #  1234567890.50.to_s(:currency, unit: '&pound;', separator: ',', delimiter: '', format: '%n %u')
  #  # => "1234567890,50 &pound;"
  #
  #  Percentage:
  #  100.to_s(:percentage)                                  # => "100.000%"
  #  100.to_s(:percentage, precision: 0)                    # => "100%"
  #  1000.to_s(:percentage, delimiter: '.', separator: ',') # => "1.000,000%"
  #  302.24398923423.to_s(:percentage, precision: 5)        # => "302.24399%"
  #  1000.to_s(:percentage, locale: :fr)                    # => "1 000,000%"
  #  100.to_s(:percentage, format: '%n  %')                 # => "100.000  %"
  #
  #  Delimited:
  #  12345678.to_s(:delimited)                     # => "12,345,678"
  #  12345678.05.to_s(:delimited)                  # => "12,345,678.05"
  #  12345678.to_s(:delimited, delimiter: '.')     # => "12.345.678"
  #  12345678.to_s(:delimited, delimiter: ',')     # => "12,345,678"
  #  12345678.05.to_s(:delimited, separator: ' ')  # => "12,345,678 05"
  #  12345678.05.to_s(:delimited, locale: :fr)     # => "12 345 678,05"
  #  98765432.98.to_s(:delimited, delimiter: ' ', separator: ',')
  #  # => "98 765 432,98"
  #
  #  Rounded:
  #  111.2345.to_s(:rounded)                                      # => "111.235"
  #  111.2345.to_s(:rounded, precision: 2)                        # => "111.23"
  #  13.to_s(:rounded, precision: 5)                              # => "13.00000"
  #  389.32314.to_s(:rounded, precision: 0)                       # => "389"
  #  111.2345.to_s(:rounded, significant: true)                   # => "111"
  #  111.2345.to_s(:rounded, precision: 1, significant: true)     # => "100"
  #  13.to_s(:rounded, precision: 5, significant: true)           # => "13.000"
  #  111.234.to_s(:rounded, locale: :fr)                          # => "111,234"
  #  13.to_s(:rounded, precision: 5, significant: true, strip_insignificant_zeros: true)
  #  # => "13"
  #  389.32314.to_s(:rounded, precision: 4, significant: true)    # => "389.3"
  #  1111.2345.to_s(:rounded, precision: 2, separator: ',', delimiter: '.')
  #  # => "1.111,23"
  #
  #  Human-friendly size in Bytes:
  #  123.to_s(:human_size)                                   # => "123 Bytes"
  #  1234.to_s(:human_size)                                  # => "1.21 KB"
  #  12345.to_s(:human_size)                                 # => "12.1 KB"
  #  1234567.to_s(:human_size)                               # => "1.18 MB"
  #  1234567890.to_s(:human_size)                            # => "1.15 GB"
  #  1234567890123.to_s(:human_size)                         # => "1.12 TB"
  #  1234567890123456.to_s(:human_size)                      # => "1.1 PB"
  #  1234567890123456789.to_s(:human_size)                   # => "1.07 EB"
  #  1234567.to_s(:human_size, precision: 2)                 # => "1.2 MB"
  #  483989.to_s(:human_size, precision: 2)                  # => "470 KB"
  #  1234567.to_s(:human_size, precision: 2, separator: ',') # => "1,2 MB"
  #  1234567890123.to_s(:human_size, precision: 5)           # => "1.1228 TB"
  #  524288000.to_s(:human_size, precision: 5)               # => "500 MB"
  #
  #  Human-friendly format:
  #  123.to_s(:human)                                       # => "123"
  #  1234.to_s(:human)                                      # => "1.23 Thousand"
  #  12345.to_s(:human)                                     # => "12.3 Thousand"
  #  1234567.to_s(:human)                                   # => "1.23 Million"
  #  1234567890.to_s(:human)                                # => "1.23 Billion"
  #  1234567890123.to_s(:human)                             # => "1.23 Trillion"
  #  1234567890123456.to_s(:human)                          # => "1.23 Quadrillion"
  #  1234567890123456789.to_s(:human)                       # => "1230 Quadrillion"
  #  489939.to_s(:human, precision: 2)                      # => "490 Thousand"
  #  489939.to_s(:human, precision: 4)                      # => "489.9 Thousand"
  #  1234567.to_s(:human, precision: 4,
  #                   significant: false)                   # => "1.2346 Million"
  #  1234567.to_s(:human, precision: 1,
  #                   separator: ',',
  #                   significant: false)                   # => "1,2 Million"
  def to_s(format = nil, options = nil)
    case format
    when nil
      super()
    when Integer, String
      super(format)
    when :phone
      ActiveSupport::NumberHelper.number_to_phone(self, options || {})
    when :currency
      ActiveSupport::NumberHelper.number_to_currency(self, options || {})
    when :percentage
      ActiveSupport::NumberHelper.number_to_percentage(self, options || {})
    when :delimited
      ActiveSupport::NumberHelper.number_to_delimited(self, options || {})
    when :rounded
      ActiveSupport::NumberHelper.number_to_rounded(self, options || {})
    when :human
      ActiveSupport::NumberHelper.number_to_human(self, options || {})
    when :human_size
      ActiveSupport::NumberHelper.number_to_human_size(self, options || {})
    when Symbol
      super()
    else
      super(format)
    end
  end
end

# Ruby 2.4+ unifies Fixnum & Bignum into Integer.
if 0.class == Integer
  Integer.prepend ActiveSupport::NumericWithFormat
else
  Fixnum.prepend ActiveSupport::NumericWithFormat
  Bignum.prepend ActiveSupport::NumericWithFormat
end
Float.prepend ActiveSupport::NumericWithFormat
BigDecimal.prepend ActiveSupport::NumericWithFormat
