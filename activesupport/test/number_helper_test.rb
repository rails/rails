# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/number_helper"
require "active_support/core_ext/string/output_safety"

module ActiveSupport
  module NumberHelper
    class NumberHelperTest < ActiveSupport::TestCase
      class TestClassWithInstanceNumberHelpers
        include ActiveSupport::NumberHelper
      end

      class TestClassWithClassNumberHelpers
        extend ActiveSupport::NumberHelper
      end

      def setup
        @instance_with_helpers = TestClassWithInstanceNumberHelpers.new
      end

      def kilobytes(number)
        number * 1024
      end

      def megabytes(number)
        kilobytes(number) * 1024
      end

      def gigabytes(number)
        megabytes(number) * 1024
      end

      def terabytes(number)
        gigabytes(number) * 1024
      end

      def petabytes(number)
        terabytes(number) * 1024
      end

      def exabytes(number)
        petabytes(number) * 1024
      end

      def test_number_to_phone
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal("555-1234", number_helper.number_to_phone(5551234))
          assert_equal("800-555-1212", number_helper.number_to_phone(8005551212))
          assert_equal("(800) 555-1212", number_helper.number_to_phone(8005551212, area_code: true))
          assert_equal("", number_helper.number_to_phone("", area_code: true))
          assert_equal("800 555 1212", number_helper.number_to_phone(8005551212, delimiter: " "))
          assert_equal("(800) 555-1212 x 123", number_helper.number_to_phone(8005551212, area_code: true, extension: 123))
          assert_equal("800-555-1212", number_helper.number_to_phone(8005551212, extension: "  "))
          assert_equal("555.1212", number_helper.number_to_phone(5551212, delimiter: "."))
          assert_equal("800-555-1212", number_helper.number_to_phone("8005551212"))
          assert_equal("+1-800-555-1212", number_helper.number_to_phone(8005551212, country_code: 1))
          assert_equal("+18005551212", number_helper.number_to_phone(8005551212, country_code: 1, delimiter: ""))
          assert_equal("22-555-1212", number_helper.number_to_phone(225551212))
          assert_equal("+45-22-555-1212", number_helper.number_to_phone(225551212, country_code: 45))
          assert_equal("(755) 6123-4567", number_helper.number_to_phone(75561234567, pattern: /(\d{3,4})(\d{4})(\d{4})/, area_code: true))
          assert_equal("133-1234-5678", number_helper.number_to_phone(13312345678, pattern: /(\d{3})(\d{4})(\d{4})/))
        end
      end

      def test_number_to_currency
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal("$1,234,567,890.50", number_helper.number_to_currency(1234567890.50))
          assert_equal("$1,234,567,890.51", number_helper.number_to_currency(1234567890.506))
          assert_equal("-$1,234,567,890.50", number_helper.number_to_currency(-1234567890.50))
          assert_equal("-$ 1,234,567,890.50", number_helper.number_to_currency(-1234567890.50, format: "%u %n"))
          assert_equal("($1,234,567,890.50)", number_helper.number_to_currency(-1234567890.50, negative_format: "(%u%n)"))
          assert_equal("$1,234,567,892", number_helper.number_to_currency(1234567891.50, precision: 0))
          assert_equal("$1,234,567,891", number_helper.number_to_currency(1234567891.50, precision: 0, round_mode: :down))
          assert_equal("$1,234,567,890.5", number_helper.number_to_currency(1234567890.50, precision: 1))
          assert_equal("&pound;1234567890,50", number_helper.number_to_currency(1234567890.50, unit: "&pound;", separator: ",", delimiter: ""))
          assert_equal("$1,234,567,890.50", number_helper.number_to_currency("1234567890.50"))
          assert_equal("1,234,567,890.50 K&#269;", number_helper.number_to_currency("1234567890.50", unit: "K&#269;", format: "%n %u"))
          assert_equal("1,234,567,890.50 - K&#269;", number_helper.number_to_currency("-1234567890.50", unit: "K&#269;", format: "%n %u", negative_format: "%n - %u"))
          assert_equal("0.00", number_helper.number_to_currency(+0.0, unit: "", negative_format: "(%n)"))
          assert_equal("$0", number_helper.number_to_currency(-0.456789, precision: 0))
          assert_equal("$0.0", number_helper.number_to_currency(-0.0456789, precision: 1))
          assert_equal("$0.00", number_helper.number_to_currency(-0.00456789, precision: 2))
          assert_equal("-$1", number_helper.number_to_currency(-0.5, precision: 0))
          assert_equal("$1,11", number_helper.number_to_currency("1,11"))
          assert_equal("$0,11", number_helper.number_to_currency("0,11"))
          assert_equal("$,11", number_helper.number_to_currency(",11"))
          assert_equal("-$1,11", number_helper.number_to_currency("-1,11"))
          assert_equal("-$0,11", number_helper.number_to_currency("-0,11"))
          assert_equal("-$,11", number_helper.number_to_currency("-,11"))
          assert_equal("$0.00", number_helper.number_to_currency(-0.0))
          assert_equal("$0.00", number_helper.number_to_currency("-0.0"))
        end
      end

      def test_number_to_percentage
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal("100.000%", number_helper.number_to_percentage(100))
          assert_equal("100%", number_helper.number_to_percentage(100, precision: 0))
          assert_equal("302.06%", number_helper.number_to_percentage(302.0574, precision: 2))
          assert_equal("302.05%", number_helper.number_to_percentage(302.0574, precision: 2, round_mode: :down))
          assert_equal("100.000%", number_helper.number_to_percentage("100"))
          assert_equal("1000.000%", number_helper.number_to_percentage("1000"))
          assert_equal("123.4%", number_helper.number_to_percentage(123.400, precision: 3, strip_insignificant_zeros: true))
          assert_equal("1.000,000%", number_helper.number_to_percentage(1000, delimiter: ".", separator: ","))
          assert_equal("1000.000  %", number_helper.number_to_percentage(1000, format: "%n  %"))
          assert_equal("98a%", number_helper.number_to_percentage("98a"))
          assert_equal("NaN%", number_helper.number_to_percentage(Float::NAN))
          assert_equal("Inf%", number_helper.number_to_percentage(Float::INFINITY))
          assert_equal("NaN%", number_helper.number_to_percentage(Float::NAN, precision: 0))
          assert_equal("Inf%", number_helper.number_to_percentage(Float::INFINITY, precision: 0))
          assert_equal("NaN%", number_helper.number_to_percentage(Float::NAN, precision: 1))
          assert_equal("Inf%", number_helper.number_to_percentage(Float::INFINITY, precision: 1))
          assert_equal("1000%", number_helper.number_to_percentage(1000, precision: nil))
          assert_equal("1000%", number_helper.number_to_percentage(1000, precision: nil))
          assert_equal("1000.1%", number_helper.number_to_percentage(1000.1, precision: nil))
          assert_equal("-0.13 %", number_helper.number_to_percentage("-0.13", precision: nil, format: "%n %"))
        end
      end

      def test_to_delimited
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal("12,345,678", number_helper.number_to_delimited(12345678))
          assert_equal("0", number_helper.number_to_delimited(0))
          assert_equal("123", number_helper.number_to_delimited(123))
          assert_equal("123,456", number_helper.number_to_delimited(123456))
          assert_equal("123,456.78", number_helper.number_to_delimited(123456.78))
          assert_equal("123,456.789", number_helper.number_to_delimited(123456.789))
          assert_equal("123,456.78901", number_helper.number_to_delimited(123456.78901))
          assert_equal("123,456,789.78901", number_helper.number_to_delimited(123456789.78901))
          assert_equal("0.78901", number_helper.number_to_delimited(0.78901))
          assert_equal("123,456.78", number_helper.number_to_delimited("123456.78"))
          assert_equal("1,23,456.78", number_helper.number_to_delimited("123456.78", delimiter_pattern: /(\d+?)(?=(\d\d)+(\d)(?!\d))/))
          assert_equal("123,456.78", number_helper.number_to_delimited("123456.78".html_safe))
        end
      end

      def test_to_delimited_with_options_hash
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "12 345 678", number_helper.number_to_delimited(12345678, delimiter: " ")
          assert_equal "12,345,678-05", number_helper.number_to_delimited(12345678.05, separator: "-")
          assert_equal "12.345.678,05", number_helper.number_to_delimited(12345678.05, separator: ",", delimiter: ".")
        end
      end

      def test_to_rounded
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal("-111.235", number_helper.number_to_rounded(-111.2346))
          assert_equal("111.235", number_helper.number_to_rounded(111.2346))
          assert_equal("31.83", number_helper.number_to_rounded(31.825, precision: 2))
          assert_equal("111.23", number_helper.number_to_rounded(111.2346, precision: 2))
          assert_equal("111.24", number_helper.number_to_rounded(111.2346, precision: 2, round_mode: :up))
          assert_equal("111.00", number_helper.number_to_rounded(111, precision: 2))
          assert_equal("111.235", number_helper.number_to_rounded("111.2346"))
          assert_equal("31.83", number_helper.number_to_rounded("31.825", precision: 2))
          assert_equal("3268", number_helper.number_to_rounded((32.6751 * 100.00), precision: 0))
          assert_equal("112", number_helper.number_to_rounded(111.50, precision: 0))
          assert_equal("1234567892", number_helper.number_to_rounded(1234567891.50, precision: 0))
          assert_equal("0", number_helper.number_to_rounded(0, precision: 0))
          assert_equal("0.00100", number_helper.number_to_rounded(0.001, precision: 5))
          assert_equal("0.001", number_helper.number_to_rounded(0.00111, precision: 3))
          assert_equal("10.00", number_helper.number_to_rounded(9.995, precision: 2))
          assert_equal("11.00", number_helper.number_to_rounded(10.995, precision: 2))
          assert_equal("0.00", number_helper.number_to_rounded(-0.001, precision: 2))

          assert_equal("111.23460000000000000000", number_helper.number_to_rounded(111.2346, precision: 20))
          assert_equal("111.23460000000000000000", number_helper.number_to_rounded(Rational(1112346, 10000), precision: 20))
          assert_equal("111.23460000000000000000", number_helper.number_to_rounded("111.2346", precision: 20))
          assert_equal("111.23460000000000000000", number_helper.number_to_rounded(BigDecimal(111.2346, Float::DIG), precision: 20))
          assert_equal("111.2346" + "0" * 96, number_helper.number_to_rounded("111.2346", precision: 100))
          assert_equal("111.2346", number_helper.number_to_rounded(Rational(1112346, 10000), precision: 4))
          assert_equal("0.00", number_helper.number_to_rounded(Rational(0, 1), precision: 2))
        end
      end

      def test_to_rounded_with_custom_delimiter_and_separator
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "31,83",       number_helper.number_to_rounded(31.825, precision: 2, separator: ",")
          assert_equal "1.231,83",    number_helper.number_to_rounded(1231.825, precision: 2, separator: ",", delimiter: ".")
        end
      end

      def test_to_rounded_with_significant_digits
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "124000", number_helper.number_to_rounded(123987, precision: 3, significant: true)
          assert_equal "120000000", number_helper.number_to_rounded(123987876, precision: 2, significant: true)
          assert_equal "40000", number_helper.number_to_rounded("43523", precision: 1, significant: true)
          assert_equal "9775", number_helper.number_to_rounded(9775, precision: 4, significant: true)
          assert_equal "5.4", number_helper.number_to_rounded(5.3923, precision: 2, significant: true)
          assert_equal "5", number_helper.number_to_rounded(5.3923, precision: 1, significant: true)
          assert_equal "1", number_helper.number_to_rounded(1.232, precision: 1, significant: true)
          assert_equal "7", number_helper.number_to_rounded(7, precision: 1, significant: true)
          assert_equal "1", number_helper.number_to_rounded(1, precision: 1, significant: true)
          assert_equal "53", number_helper.number_to_rounded(52.7923, precision: 2, significant: true)
          assert_equal "9775.00", number_helper.number_to_rounded(9775, precision: 6, significant: true)
          assert_equal "5.392900", number_helper.number_to_rounded(5.3929, precision: 7, significant: true)
          assert_equal "0.0", number_helper.number_to_rounded(0, precision: 2, significant: true)
          assert_equal "0", number_helper.number_to_rounded(0, precision: 1, significant: true)
          assert_equal "0.0001", number_helper.number_to_rounded(0.0001, precision: 1, significant: true)
          assert_equal "0.000100", number_helper.number_to_rounded(0.0001, precision: 3, significant: true)
          assert_equal "0.0001", number_helper.number_to_rounded(0.0001111, precision: 1, significant: true)
          assert_equal "10.0", number_helper.number_to_rounded(9.995, precision: 3, significant: true)
          assert_equal "9.99", number_helper.number_to_rounded(9.994, precision: 3, significant: true)
          assert_equal "11.0", number_helper.number_to_rounded(10.995, precision: 3, significant: true)
          assert_equal "123000", number_helper.number_to_rounded(123987, precision: 3, significant: true, round_mode: :down)

          assert_equal "9775.0000000000000000", number_helper.number_to_rounded(9775, precision: 20, significant: true)
          assert_equal "9775.0000000000000000", number_helper.number_to_rounded(9775.0, precision: 20, significant: true)
          assert_equal "9775.0000000000000000", number_helper.number_to_rounded(Rational(9775, 1), precision: 20, significant: true)
          assert_equal "97.750000000000000000", number_helper.number_to_rounded(Rational(9775, 100), precision: 20, significant: true)
          assert_equal "9775.0000000000000000", number_helper.number_to_rounded(BigDecimal(9775), precision: 20, significant: true)
          assert_equal "9775.0000000000000000", number_helper.number_to_rounded("9775", precision: 20, significant: true)
          assert_equal "9775." + "0" * 96, number_helper.number_to_rounded("9775", precision: 100, significant: true)
          assert_equal("97.7", number_helper.number_to_rounded(Rational(9772, 100), precision: 3, significant: true))
          assert_equal "28729870200000000000000", number_helper.number_to_rounded(0.287298702e23.to_d, precision: 0, significant: true)
          assert_equal "-Inf", number_helper.number_to_rounded(-Float::INFINITY, precision: 0, significant: true)
        end
      end

      def test_to_rounded_with_strip_insignificant_zeros
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "9775.43", number_helper.number_to_rounded(9775.43, precision: 4, strip_insignificant_zeros: true)
          assert_equal "9775.2", number_helper.number_to_rounded(9775.2, precision: 6, significant: true, strip_insignificant_zeros: true)
          assert_equal "0", number_helper.number_to_rounded(0, precision: 6, significant: true, strip_insignificant_zeros: true)
        end
      end

      def test_to_rounded_with_significant_true_and_zero_precision
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          # Zero precision with significant is a mistake (would always return zero),
          # so we treat it as if significant was false (increases backwards compatibility for number_to_human_size)
          assert_equal "124", number_helper.number_to_rounded(123.987, precision: 0, significant: true)
          assert_equal "12", number_helper.number_to_rounded(12, precision: 0, significant: true)
          assert_equal "12", number_helper.number_to_rounded("12.3", precision: 0, significant: true)
        end
      end

      def test_number_number_to_human_size
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "0 Bytes",   number_helper.number_to_human_size(0)
          assert_equal "1 Byte",    number_helper.number_to_human_size(1)
          assert_equal "3 Bytes",   number_helper.number_to_human_size(3.14159265)
          assert_equal "123 Bytes", number_helper.number_to_human_size(123.0)
          assert_equal "123 Bytes", number_helper.number_to_human_size(123)
          assert_equal "1.21 KB",    number_helper.number_to_human_size(1234)
          assert_equal "12.1 KB",   number_helper.number_to_human_size(12345)
          assert_equal "1.18 MB",    number_helper.number_to_human_size(1234567)
          assert_equal "1.15 GB",    number_helper.number_to_human_size(1234567890)
          assert_equal "1.12 TB",    number_helper.number_to_human_size(1234567890123)
          assert_equal "1.1 PB",   number_helper.number_to_human_size(1234567890123456)
          assert_equal "1.07 EB",   number_helper.number_to_human_size(1234567890123456789)
          assert_equal "1030 EB",   number_helper.number_to_human_size(exabytes(1026))
          assert_equal "444 KB",    number_helper.number_to_human_size(kilobytes(444))
          assert_equal "1020 MB",   number_helper.number_to_human_size(megabytes(1023))
          assert_equal "3 TB",      number_helper.number_to_human_size(terabytes(3))
          assert_equal "1.2 MB",   number_helper.number_to_human_size(1234567, precision: 2)
          assert_equal "1.1 MB",   number_helper.number_to_human_size(1234567, precision: 2, round_mode: :down)
          assert_equal "3 Bytes",   number_helper.number_to_human_size(3.14159265, precision: 4)
          assert_equal "123 Bytes", number_helper.number_to_human_size("123")
          assert_equal "1 KB",   number_helper.number_to_human_size(kilobytes(1.0123), precision: 2)
          assert_equal "1.01 KB",   number_helper.number_to_human_size(kilobytes(1.0100), precision: 4)
          assert_equal "10 KB",   number_helper.number_to_human_size(kilobytes(10.000), precision: 4)
          assert_equal "1 Byte",   number_helper.number_to_human_size(1.1)
          assert_equal "10 Bytes", number_helper.number_to_human_size(10)
        end
      end

      def test_number_to_human_size_with_options_hash
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "1.2 MB",   number_helper.number_to_human_size(1234567, precision: 2)
          assert_equal "3 Bytes",   number_helper.number_to_human_size(3.14159265, precision: 4)
          assert_equal "1 KB",   number_helper.number_to_human_size(kilobytes(1.0123), precision: 2)
          assert_equal "1.01 KB",   number_helper.number_to_human_size(kilobytes(1.0100), precision: 4)
          assert_equal "10 KB",     number_helper.number_to_human_size(kilobytes(10.000), precision: 4)
          assert_equal "1 TB", number_helper.number_to_human_size(1234567890123, precision: 1)
          assert_equal "500 MB", number_helper.number_to_human_size(524288000, precision: 3)
          assert_equal "10 MB", number_helper.number_to_human_size(9961472, precision: 0)
          assert_equal "40 KB", number_helper.number_to_human_size(41010, precision: 1)
          assert_equal "40 KB", number_helper.number_to_human_size(41100, precision: 2)
          assert_equal "50 KB", number_helper.number_to_human_size(41100, precision: 1, round_mode: :up)
          assert_equal "1.0 KB",   number_helper.number_to_human_size(kilobytes(1.0123), precision: 2, strip_insignificant_zeros: false)
          assert_equal "1.012 KB",   number_helper.number_to_human_size(kilobytes(1.0123), precision: 3, significant: false)
          assert_equal "1 KB",   number_helper.number_to_human_size(kilobytes(1.0123), precision: 0, significant: true) # ignores significant it precision is 0
        end
      end

      def test_number_to_human_size_with_custom_delimiter_and_separator
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "1,01 KB",     number_helper.number_to_human_size(kilobytes(1.0123), precision: 3, separator: ",")
          assert_equal "1,01 KB",     number_helper.number_to_human_size(kilobytes(1.0100), precision: 4, separator: ",")
          assert_equal "1.000,1 TB",  number_helper.number_to_human_size(terabytes(1000.1), precision: 5, delimiter: ".", separator: ",")
        end
      end

      def test_number_to_human
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "-123", number_helper.number_to_human(-123)
          assert_equal "-0.5", number_helper.number_to_human(-0.5)
          assert_equal "0",   number_helper.number_to_human(0)
          assert_equal "0.5", number_helper.number_to_human(0.5)
          assert_equal "123", number_helper.number_to_human(123)
          assert_equal "1.23 Thousand", number_helper.number_to_human(1234)
          assert_equal "12.3 Thousand", number_helper.number_to_human(12345)
          assert_equal "1.23 Million", number_helper.number_to_human(1234567)
          assert_equal "1.23 Billion", number_helper.number_to_human(1234567890)
          assert_equal "1.23 Trillion", number_helper.number_to_human(1234567890123)
          assert_equal "1.23 Quadrillion", number_helper.number_to_human(1234567890123456)
          assert_equal "1230 Quadrillion", number_helper.number_to_human(1234567890123456789)
          assert_equal "490 Thousand", number_helper.number_to_human(489939, precision: 2)
          assert_equal "489.9 Thousand", number_helper.number_to_human(489939, precision: 4)
          assert_equal "489 Thousand", number_helper.number_to_human(489000, precision: 4)
          assert_equal "480 Thousand", number_helper.number_to_human(489939, precision: 2, round_mode: :down)
          assert_equal "489.0 Thousand", number_helper.number_to_human(489000, precision: 4, strip_insignificant_zeros: false)
          assert_equal "1.2346 Million", number_helper.number_to_human(1234567, precision: 4, significant: false)
          assert_equal "1,2 Million", number_helper.number_to_human(1234567, precision: 1, significant: false, separator: ",")
          assert_equal "1 Million", number_helper.number_to_human(1234567, precision: 0, significant: true, separator: ",") # significant forced to false
          assert_equal "1 Million", number_helper.number_to_human(999999)
          assert_equal "1 Billion", number_helper.number_to_human(999999999)
        end
      end

      def test_number_to_human_with_custom_units
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          # Only integers
          volume = { unit: "ml", thousand: "lt", million: "m3" }
          assert_equal "123 lt", number_helper.number_to_human(123456, units: volume)
          assert_equal "12 ml", number_helper.number_to_human(12, units: volume)
          assert_equal "1.23 m3", number_helper.number_to_human(1234567, units: volume)

          # Including fractionals
          distance = { mili: "mm", centi: "cm", deci: "dm", unit: "m", ten: "dam", hundred: "hm", thousand: "km" }
          assert_equal "1.23 mm", number_helper.number_to_human(0.00123, units: distance)
          assert_equal "1.23 cm", number_helper.number_to_human(0.0123, units: distance)
          assert_equal "1.23 dm", number_helper.number_to_human(0.123, units: distance)
          assert_equal "1.23 m", number_helper.number_to_human(1.23, units: distance)
          assert_equal "1.23 dam", number_helper.number_to_human(12.3, units: distance)
          assert_equal "1.23 hm", number_helper.number_to_human(123, units: distance)
          assert_equal "1.23 km", number_helper.number_to_human(1230, units: distance)
          assert_equal "1.23 km", number_helper.number_to_human(1230, units: distance)
          assert_equal "1.23 km", number_helper.number_to_human(1230, units: distance)
          assert_equal "12.3 km", number_helper.number_to_human(12300, units: distance)

          # The quantifiers don't need to be a continuous sequence
          gangster = { hundred: "hundred bucks", million: "thousand quids" }
          assert_equal "1 hundred bucks", number_helper.number_to_human(100, units: gangster)
          assert_equal "25 hundred bucks", number_helper.number_to_human(2500, units: gangster)
          assert_equal "1000 hundred bucks", number_helper.number_to_human(100_000, units: gangster)
          assert_equal "1 thousand quids", number_helper.number_to_human(999_999, units: gangster)
          assert_equal "1 thousand quids", number_helper.number_to_human(1_000_000, units: gangster)
          assert_equal "25 thousand quids", number_helper.number_to_human(25000000, units: gangster)
          assert_equal "12300 thousand quids", number_helper.number_to_human(12345000000, units: gangster)

          # Spaces are stripped from the resulting string
          assert_equal "4", number_helper.number_to_human(4, units: { unit: "", ten: "tens " })
          assert_equal "4.5  tens", number_helper.number_to_human(45, units: { unit: "", ten: " tens   " })

          # Uses only the provided units and does not try to use larger ones
          assert_equal "1000 kilometers", number_helper.number_to_human(1_000_000, units: { unit: "meter", thousand: "kilometers" })
        end
      end

      def test_number_to_human_with_custom_units_that_are_missing_the_needed_key
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "123", number_helper.number_to_human(123, units: { thousand: "k" })
          assert_equal "123", number_helper.number_to_human(123, units: {})
        end
      end

      def test_number_to_human_with_custom_format
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal "123 times Thousand", number_helper.number_to_human(123456, format: "%n times %u")
          volume = { unit: "ml", thousand: "lt", million: "m3" }
          assert_equal "123.lt", number_helper.number_to_human(123456, units: volume, format: "%n.%u")
        end
      end

      def test_number_helpers_should_return_nil_when_given_nil
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_nil number_helper.number_to_phone(nil)
          assert_nil number_helper.number_to_currency(nil)
          assert_nil number_helper.number_to_percentage(nil)
          assert_nil number_helper.number_to_delimited(nil)
          assert_nil number_helper.number_to_rounded(nil)
          assert_nil number_helper.number_to_human_size(nil)
          assert_nil number_helper.number_to_human(nil)
        end
      end

      def test_number_helpers_do_not_mutate_options_hash
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          options = { "raise" => true }

          number_helper.number_to_phone(1, options)
          assert_equal({ "raise" => true }, options)

          number_helper.number_to_currency(1, options)
          assert_equal({ "raise" => true }, options)

          number_helper.number_to_percentage(1, options)
          assert_equal({ "raise" => true }, options)

          number_helper.number_to_delimited(1, options)
          assert_equal({ "raise" => true }, options)

          number_helper.number_to_rounded(1, options)
          assert_equal({ "raise" => true }, options)

          number_helper.number_to_human_size(1, options)
          assert_equal({ "raise" => true }, options)

          number_helper.number_to_human(1, options)
          assert_equal({ "raise" => true }, options)
        end
      end

      def test_number_helpers_should_return_non_numeric_param_unchanged
        [@instance_with_helpers, TestClassWithClassNumberHelpers, ActiveSupport::NumberHelper].each do |number_helper|
          assert_equal("+1-x x 123", number_helper.number_to_phone("x", country_code: 1, extension: 123))
          assert_equal("x", number_helper.number_to_phone("x"))
          assert_equal("$x.", number_helper.number_to_currency("x."))
          assert_equal("$x", number_helper.number_to_currency("x"))
          assert_equal("x%", number_helper.number_to_percentage("x"))
          assert_equal("x", number_helper.number_to_delimited("x"))
          assert_equal("x.", number_helper.number_to_rounded("x."))
          assert_equal("x", number_helper.number_to_rounded("x"))
          assert_equal "x", number_helper.number_to_human_size("x")
          assert_equal "x", number_helper.number_to_human("x")
        end
      end
    end
  end
end
