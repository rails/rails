# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/time"
require "active_support/core_ext/numeric"
require "active_support/core_ext/integer"

class NumericExtTimeAndDateTimeTest < ActiveSupport::TestCase
  def setup
    @now = Time.local(2005, 2, 10, 15, 30, 45)
    @dtnow = DateTime.civil(2005, 2, 10, 15, 30, 45)
    @seconds = {
      1.minute   => 60,
      10.minutes => 600,
      1.hour + 15.minutes => 4500,
      2.days + 4.hours + 30.minutes => 189000,
      5.years + 1.month + 1.fortnight => 161624106
    }
  end

  def test_units
    @seconds.each do |actual, expected|
      assert_equal expected, actual
    end
  end

  def test_irregular_durations
    assert_equal @now.advance(days: 3000), 3000.days.since(@now)
    assert_equal @now.advance(months: 1), 1.month.since(@now)
    assert_equal @now.advance(months: -1), 1.month.until(@now)
    assert_equal @now.advance(years: 20), 20.years.since(@now)
    assert_equal @dtnow.advance(days: 3000), 3000.days.since(@dtnow)
    assert_equal @dtnow.advance(months: 1), 1.month.since(@dtnow)
    assert_equal @dtnow.advance(months: -1), 1.month.until(@dtnow)
    assert_equal @dtnow.advance(years: 20), 20.years.since(@dtnow)
  end

  def test_duration_addition
    assert_equal @now.advance(days: 1).advance(months: 1), (1.day + 1.month).since(@now)
    assert_equal @now.advance(days: 7), (1.week + 5.seconds - 5.seconds).since(@now)
    assert_equal @now.advance(years: 2), (4.years - 2.years).since(@now)
    assert_equal @dtnow.advance(days: 1).advance(months: 1), (1.day + 1.month).since(@dtnow)
    assert_equal @dtnow.advance(days: 7), (1.week + 5.seconds - 5.seconds).since(@dtnow)
    assert_equal @dtnow.advance(years: 2), (4.years - 2.years).since(@dtnow)
  end

  def test_time_plus_duration
    assert_equal @now + 8, @now + 8.seconds
    assert_equal @now + 22.9, @now + 22.9.seconds
    assert_equal @now.advance(days: 15), @now + 15.days
    assert_equal @now.advance(months: 1), @now + 1.month
    assert_equal @dtnow.since(8), @dtnow + 8.seconds
    assert_equal @dtnow.since(22.9), @dtnow + 22.9.seconds
    assert_equal @dtnow.advance(days: 15), @dtnow + 15.days
    assert_equal @dtnow.advance(months: 1), @dtnow + 1.month
  end

  def test_chaining_duration_operations
    assert_equal @now.advance(days: 2).advance(months: -3), @now + 2.days - 3.months
    assert_equal @now.advance(days: 1).advance(months: 2), @now + 1.day + 2.months
    assert_equal @dtnow.advance(days: 2).advance(months: -3), @dtnow + 2.days - 3.months
    assert_equal @dtnow.advance(days: 1).advance(months: 2), @dtnow + 1.day + 2.months
  end

  def test_duration_after_conversion_is_no_longer_accurate
    assert_equal (1.year / 12).to_i.seconds.since(@now), 1.month.to_i.seconds.since(@now)
    assert_equal 365.2425.days.to_f.seconds.since(@now), 1.year.to_f.seconds.since(@now)
    assert_equal (1.year / 12).to_i.seconds.since(@dtnow), 1.month.to_i.seconds.since(@dtnow)
    assert_equal 365.2425.days.to_f.seconds.since(@dtnow), 1.year.to_f.seconds.since(@dtnow)
  end

  def test_add_one_year_to_leap_day
    assert_equal Time.utc(2005, 2, 28, 15, 15, 10), Time.utc(2004, 2, 29, 15, 15, 10) + 1.year
    assert_equal DateTime.civil(2005, 2, 28, 15, 15, 10), DateTime.civil(2004, 2, 29, 15, 15, 10) + 1.year
  end

  def test_in_milliseconds
    assert_equal 10_000, 10.seconds.in_milliseconds
  end
end

class NumericExtDateTest < ActiveSupport::TestCase
  def setup
    @today = Date.today
  end

  def test_date_plus_duration
    assert_equal @today + 1, @today + 1.day
    assert_equal @today >> 1, @today + 1.month
    assert_equal @today.to_time.since(1), @today + 1.second
    assert_equal @today.to_time.since(60), @today + 1.minute
    assert_equal @today.to_time.since(60 * 60), @today + 1.hour
  end

  def test_chaining_duration_operations
    assert_equal @today.advance(days: 2).advance(months: -3), @today + 2.days - 3.months
    assert_equal @today.advance(days: 1).advance(months: 2), @today + 1.day + 2.months
  end

  def test_add_one_year_to_leap_day
    assert_equal Date.new(2005, 2, 28), Date.new(2004, 2, 29) + 1.year
  end
end

class NumericExtSizeTest < ActiveSupport::TestCase
  def test_unit_in_terms_of_another
    assert_equal 1024.bytes, 1.kilobyte
    assert_equal 1024.kilobytes, 1.megabyte
    assert_equal 3584.0.kilobytes, 3.5.megabytes
    assert_equal 3584.0.megabytes, 3.5.gigabytes
    assert_equal 1.kilobyte**4, 1.terabyte
    assert_equal 1024.kilobytes + 2.megabytes, 3.megabytes
    assert_equal 2.gigabytes / 4, 512.megabytes
    assert_equal 256.megabytes * 20 + 5.gigabytes, 10.gigabytes
    assert_equal 1.kilobyte**5, 1.petabyte
    assert_equal 1.kilobyte**6, 1.exabyte
    assert_equal 1.kilobyte**7, 1.zettabyte
  end

  def test_units_as_bytes_independently
    assert_equal 3145728, 3.megabytes
    assert_equal 3145728, 3.megabyte
    assert_equal 3072, 3.kilobytes
    assert_equal 3072, 3.kilobyte
    assert_equal 3221225472, 3.gigabytes
    assert_equal 3221225472, 3.gigabyte
    assert_equal 3298534883328, 3.terabytes
    assert_equal 3298534883328, 3.terabyte
    assert_equal 3377699720527872, 3.petabytes
    assert_equal 3377699720527872, 3.petabyte
    assert_equal 3458764513820540928, 3.exabytes
    assert_equal 3458764513820540928, 3.exabyte
    assert_equal 3541774862152233910272, 3.zettabytes
    assert_equal 3541774862152233910272, 3.zettabyte
  end
end

class NumericExtFormattingTest < ActiveSupport::TestCase
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

  def zettabytes(number)
    exabytes(number) * 1024
  end

  def test_to_fs__phone
    assert_equal("555-1234", 5551234.to_fs(:phone))
    assert_equal("555-1234", 5551234.to_formatted_s(:phone))
    assert_equal("800-555-1212", 8005551212.to_fs(:phone))
    assert_equal("(800) 555-1212", 8005551212.to_fs(:phone, area_code: true))
    assert_equal("800 555 1212", 8005551212.to_fs(:phone, delimiter: " "))
    assert_equal("(800) 555-1212 x 123", 8005551212.to_fs(:phone, area_code: true, extension: 123))
    assert_equal("800-555-1212", 8005551212.to_fs(:phone, extension: "  "))
    assert_equal("555.1212", 5551212.to_fs(:phone, delimiter: "."))
    assert_equal("+1-800-555-1212", 8005551212.to_fs(:phone, country_code: 1))
    assert_equal("+18005551212", 8005551212.to_fs(:phone, country_code: 1, delimiter: ""))
    assert_equal("22-555-1212", 225551212.to_fs(:phone))
    assert_equal("+45-22-555-1212", 225551212.to_fs(:phone, country_code: 45))
  end

  def test_to_fs__currency
    assert_equal("$1,234,567,890.50", 1234567890.50.to_fs(:currency))
    assert_equal("$1,234,567,890.50", 1234567890.50.to_formatted_s(:currency))
    assert_equal("$1,234,567,890.51", 1234567890.506.to_fs(:currency))
    assert_equal("-$1,234,567,890.50", -1234567890.50.to_fs(:currency))
    assert_equal("-$ 1,234,567,890.50", -1234567890.50.to_fs(:currency, format: "%u %n"))
    assert_equal("($1,234,567,890.50)", -1234567890.50.to_fs(:currency, negative_format: "(%u%n)"))
    assert_equal("$1,234,567,892", 1234567891.50.to_fs(:currency, precision: 0))
    assert_equal("$1,234,567,891", 1234567891.50.to_fs(:currency, precision: 0, round_mode: :down))
    assert_equal("$1,234,567,890.5", 1234567890.50.to_fs(:currency, precision: 1))
    assert_equal("&pound;1234567890,50", 1234567890.50.to_fs(:currency, unit: "&pound;", separator: ",", delimiter: ""))
  end

  def test_to_fs__rounded
    assert_equal("-111.235", -111.2346.to_fs(:rounded))
    assert_equal("-111.235", -111.2346.to_formatted_s(:rounded))
    assert_equal("111.235", 111.2346.to_fs(:rounded))
    assert_equal("31.83", 31.825.to_fs(:rounded, precision: 2))
    assert_equal("31.82", 31.825.to_fs(:rounded, precision: 2, round_mode: :down))
    assert_equal("111.23", 111.2346.to_fs(:rounded, precision: 2))
    assert_equal("111.00", 111.to_fs(:rounded, precision: 2))
    assert_equal("3268", (32.6751 * 100.00).to_fs(:rounded, precision: 0))
    assert_equal("112", 111.50.to_fs(:rounded, precision: 0))
    assert_equal("1234567892", 1234567891.50.to_fs(:rounded, precision: 0))
    assert_equal("0", 0.to_fs(:rounded, precision: 0))
    assert_equal("0.00100", 0.001.to_fs(:rounded, precision: 5))
    assert_equal("0.001", 0.00111.to_fs(:rounded, precision: 3))
    assert_equal("10.00", 9.995.to_fs(:rounded, precision: 2))
    assert_equal("11.00", 10.995.to_fs(:rounded, precision: 2))
    assert_equal("0.00", -0.001.to_fs(:rounded, precision: 2))
  end

  def test_to_fs__rounded_with_custom_delimiter_and_separator
    assert_equal "31,83",       31.825.to_fs(:rounded, precision: 2, separator: ",")
    assert_equal "1.231,83",    1231.825.to_fs(:rounded, precision: 2, separator: ",", delimiter: ".")
  end

  def test_to_fs__rounded__with_significant_digits
    assert_equal "124000", 123987.to_fs(:rounded, precision: 3, significant: true)
    assert_equal "120000000", 123987876.to_fs(:rounded, precision: 2, significant: true)
    assert_equal "9775", 9775.to_fs(:rounded, precision: 4, significant: true)
    assert_equal "5.4", 5.3923.to_fs(:rounded, precision: 2, significant: true)
    assert_equal "5", 5.3923.to_fs(:rounded, precision: 1, significant: true)
    assert_equal "1", 1.232.to_fs(:rounded, precision: 1, significant: true)
    assert_equal "7", 7.to_fs(:rounded, precision: 1, significant: true)
    assert_equal "1", 1.to_fs(:rounded, precision: 1, significant: true)
    assert_equal "53", 52.7923.to_fs(:rounded, precision: 2, significant: true)
    assert_equal "9775.00", 9775.to_fs(:rounded, precision: 6, significant: true)
    assert_equal "5.392900", 5.3929.to_fs(:rounded, precision: 7, significant: true)
    assert_equal "0.0", 0.to_fs(:rounded, precision: 2, significant: true)
    assert_equal "0", 0.to_fs(:rounded, precision: 1, significant: true)
    assert_equal "0.0001", 0.0001.to_fs(:rounded, precision: 1, significant: true)
    assert_equal "0.000100", 0.0001.to_fs(:rounded, precision: 3, significant: true)
    assert_equal "0.0001", 0.0001111.to_fs(:rounded, precision: 1, significant: true)
    assert_equal "10.0", 9.995.to_fs(:rounded, precision: 3, significant: true)
    assert_equal "9.99", 9.994.to_fs(:rounded, precision: 3, significant: true)
    assert_equal "11.0", 10.995.to_fs(:rounded, precision: 3, significant: true)
    assert_equal "10.9", 10.995.to_fs(:rounded, precision: 3, significant: true, round_mode: :down)
  end

  def test_to_fs__rounded__with_strip_insignificant_zeros
    assert_equal "9775.43", 9775.43.to_fs(:rounded, precision: 4, strip_insignificant_zeros: true)
    assert_equal "9775.2", 9775.2.to_fs(:rounded, precision: 6, significant: true, strip_insignificant_zeros: true)
    assert_equal "0", 0.to_fs(:rounded, precision: 6, significant: true, strip_insignificant_zeros: true)
  end

  def test_to_fs__rounded__with_significant_true_and_zero_precision
    # Zero precision with significant is a mistake (would always return zero),
    # so we treat it as if significant was false (increases backwards compatibility for number_to_human_size)
    assert_equal "124", 123.987.to_fs(:rounded, precision: 0, significant: true)
    assert_equal "12", 12.to_fs(:rounded, precision: 0, significant: true)
  end

  def test_to_fs__percentage
    assert_equal("100.000%", 100.to_fs(:percentage))
    assert_equal("100.000%", 100.to_formatted_s(:percentage))
    assert_equal("100%", 100.to_fs(:percentage, precision: 0))
    assert_equal("302.06%", 302.0574.to_fs(:percentage, precision: 2))
    assert_equal("302.05%", 302.0574.to_fs(:percentage, precision: 2, round_mode: :down))
    assert_equal("123.4%", 123.400.to_fs(:percentage, precision: 3, strip_insignificant_zeros: true))
    assert_equal("1.000,000%", 1000.to_fs(:percentage, delimiter: ".", separator: ","))
    assert_equal("1000.000  %", 1000.to_fs(:percentage, format: "%n  %"))
  end

  def test_to_fs__delimited
    assert_equal("12,345,678", 12345678.to_fs(:delimited))
    assert_equal("12,345,678", 12345678.to_formatted_s(:delimited))
    assert_equal("0", 0.to_fs(:delimited))
    assert_equal("123", 123.to_fs(:delimited))
    assert_equal("123,456", 123456.to_fs(:delimited))
    assert_equal("123,456.78", 123456.78.to_fs(:delimited))
    assert_equal("123,456.789", 123456.789.to_fs(:delimited))
    assert_equal("123,456.78901", 123456.78901.to_fs(:delimited))
    assert_equal("123,456,789.78901", 123456789.78901.to_fs(:delimited))
    assert_equal("0.78901", 0.78901.to_fs(:delimited))
  end

  def test_to_fs__delimited__with_options_hash
    assert_equal "12 345 678", 12345678.to_fs(:delimited, delimiter: " ")
    assert_equal "12,345,678-05", 12345678.05.to_fs(:delimited, separator: "-")
    assert_equal "12.345.678,05", 12345678.05.to_fs(:delimited, separator: ",", delimiter: ".")
    assert_equal "12.345.678,05", 12345678.05.to_fs(:delimited, delimiter: ".", separator: ",")
  end

  def test_to_fs__human_size
    assert_equal "0 Bytes",   0.to_fs(:human_size)
    assert_equal "1 Byte",    1.to_fs(:human_size)
    assert_equal "3 Bytes",   3.14159265.to_fs(:human_size)
    assert_equal "123 Bytes", 123.0.to_fs(:human_size)
    assert_equal "123 Bytes", 123.to_fs(:human_size)
    assert_equal "1.21 KB",   1234.to_fs(:human_size)
    assert_equal "12.1 KB",   12345.to_fs(:human_size)
    assert_equal "1.18 MB",   1234567.to_fs(:human_size)
    assert_equal "1.15 GB",   1234567890.to_fs(:human_size)
    assert_equal "1.12 TB",   1234567890123.to_fs(:human_size)
    assert_equal "1.1 PB",    1234567890123456.to_fs(:human_size)
    assert_equal "1.07 EB",   1234567890123456789.to_fs(:human_size)
    assert_equal "1020 EB",   exabytes(1023).to_fs(:human_size)
    assert_equal "16 ZB",     zettabytes(16).to_fs(:human_size)
    assert_equal "444 KB",    kilobytes(444).to_fs(:human_size)
    assert_equal "1020 MB",   megabytes(1023).to_fs(:human_size)
    assert_equal "3 TB",      terabytes(3).to_fs(:human_size)
    assert_equal "1.2 MB",    1234567.to_fs(:human_size, precision: 2)
    assert_equal "3 Bytes",   3.14159265.to_fs(:human_size, precision: 4)
    assert_equal "1 KB",      kilobytes(1.0123).to_fs(:human_size, precision: 2)
    assert_equal "1.01 KB",   kilobytes(1.0100).to_fs(:human_size, precision: 4)
    assert_equal "10 KB",     kilobytes(10.000).to_fs(:human_size, precision: 4)
    assert_equal "1 Byte",    1.1.to_fs(:human_size)
    assert_equal "10 Bytes",  10.to_fs(:human_size)
  end

  def test_to_fs__human_size_with_negative_number
    assert_equal "-1 Bytes",   -1.to_fs(:human_size)
    assert_equal "-3 Bytes",   -3.14159265.to_fs(:human_size)
    assert_equal "-123 Bytes", -123.to_fs(:human_size)
    assert_equal "-12.1 KB",   -12345.to_fs(:human_size)
    assert_equal "-444 KB",    kilobytes(-444).to_fs(:human_size)
    assert_equal "-1.12 TB",   -1234567890123.to_fs(:human_size)
    assert_equal "-1.01 KB",   kilobytes(-1.0100).to_fs(:human_size, precision: 4)
  end

  def test_to_fs__human_size_with_options_hash
    assert_equal "1.2 MB",   1234567.to_fs(:human_size, precision: 2)
    assert_equal "3 Bytes",  3.14159265.to_fs(:human_size, precision: 4)
    assert_equal "1 KB",     kilobytes(1.0123).to_fs(:human_size, precision: 2)
    assert_equal "1.01 KB",  kilobytes(1.0100).to_fs(:human_size, precision: 4)
    assert_equal "10 KB",    kilobytes(10.000).to_fs(:human_size, precision: 4)
    assert_equal "1 TB",     1234567890123.to_fs(:human_size, precision: 1)
    assert_equal "500 MB",   524288000.to_fs(:human_size, precision: 3)
    assert_equal "10 MB",    9961472.to_fs(:human_size, precision: 0)
    assert_equal "40 KB",    41010.to_fs(:human_size, precision: 1)
    assert_equal "40 KB",    41100.to_fs(:human_size, precision: 2)
    assert_equal "50 KB",    41100.to_fs(:human_size, precision: 1, round_mode: :up)
    assert_equal "1.0 KB",   kilobytes(1.0123).to_fs(:human_size, precision: 2, strip_insignificant_zeros: false)
    assert_equal "1.012 KB", kilobytes(1.0123).to_fs(:human_size, precision: 3, significant: false)
    assert_equal "1 KB",     kilobytes(1.0123).to_fs(:human_size, precision: 0, significant: true) # ignores significant it precision is 0
  end

  def test_to_fs__human_size_with_custom_delimiter_and_separator
    assert_equal "1,01 KB",     kilobytes(1.0123).to_fs(:human_size, precision: 3, separator: ",")
    assert_equal "1,01 KB",     kilobytes(1.0100).to_fs(:human_size, precision: 4, separator: ",")
    assert_equal "1.000,1 TB",  terabytes(1000.1).to_fs(:human_size, precision: 5, delimiter: ".", separator: ",")
  end

  def test_number_to_human
    assert_equal "-123", -123.to_fs(:human)
    assert_equal "-123", -123.to_formatted_s(:human)
    assert_equal "-0.5", -0.5.to_fs(:human)
    assert_equal "0",   0.to_fs(:human)
    assert_equal "0.5", 0.5.to_fs(:human)
    assert_equal "123", 123.to_fs(:human)
    assert_equal "1.23 Thousand", 1234.to_fs(:human)
    assert_equal "12.3 Thousand", 12345.to_fs(:human)
    assert_equal "1.23 Million", 1234567.to_fs(:human)
    assert_equal "1.23 Billion", 1234567890.to_fs(:human)
    assert_equal "1.23 Trillion", 1234567890123.to_fs(:human)
    assert_equal "1.23 Quadrillion", 1234567890123456.to_fs(:human)
    assert_equal "1230 Quadrillion", 1234567890123456789.to_fs(:human)
    assert_equal "490 Thousand", 489939.to_fs(:human, precision: 2)
    assert_equal "489.9 Thousand", 489939.to_fs(:human, precision: 4)
    assert_equal "489 Thousand", 489000.to_fs(:human, precision: 4)
    assert_equal "480 Thousand", 489939.to_fs(:human, precision: 2, round_mode: :down)
    assert_equal "489.0 Thousand", 489000.to_fs(:human, precision: 4, strip_insignificant_zeros: false)
    assert_equal "1.2346 Million", 1234567.to_fs(:human, precision: 4, significant: false)
    assert_equal "1,2 Million", 1234567.to_fs(:human, precision: 1, significant: false, separator: ",")
    assert_equal "1 Million", 1234567.to_fs(:human, precision: 0, significant: true, separator: ",") # significant forced to false
  end

  def test_number_to_human_with_custom_units
    # Only integers
    volume = { unit: "ml", thousand: "lt", million: "m3" }
    assert_equal "123 lt", 123456.to_fs(:human, units: volume)
    assert_equal "12 ml", 12.to_fs(:human, units: volume)
    assert_equal "1.23 m3", 1234567.to_fs(:human, units: volume)

    # Including fractionals
    distance = { mili: "mm", centi: "cm", deci: "dm", unit: "m", ten: "dam", hundred: "hm", thousand: "km" }
    assert_equal "1.23 mm", 0.00123.to_fs(:human, units: distance)
    assert_equal "1.23 cm", 0.0123.to_fs(:human, units: distance)
    assert_equal "1.23 dm", 0.123.to_fs(:human, units: distance)
    assert_equal "1.23 m",  1.23.to_fs(:human, units: distance)
    assert_equal "1.23 dam", 12.3.to_fs(:human, units: distance)
    assert_equal "1.23 hm", 123.to_fs(:human, units: distance)
    assert_equal "1.23 km", 1230.to_fs(:human, units: distance)
    assert_equal "1.23 km", 1230.to_fs(:human, units: distance)
    assert_equal "1.23 km", 1230.to_fs(:human, units: distance)
    assert_equal "12.3 km", 12300.to_fs(:human, units: distance)

    # The quantifiers don't need to be a continuous sequence
    gangster = { hundred: "hundred bucks", million: "thousand quids" }
    assert_equal "1 hundred bucks", 100.to_fs(:human, units: gangster)
    assert_equal "25 hundred bucks", 2500.to_fs(:human, units: gangster)
    assert_equal "25 thousand quids", 25000000.to_fs(:human, units: gangster)
    assert_equal "12300 thousand quids", 12345000000.to_fs(:human, units: gangster)

    # Spaces are stripped from the resulting string
    assert_equal "4", 4.to_fs(:human, units: { unit: "", ten: "tens " })
    assert_equal "4.5  tens", 45.to_fs(:human, units: { unit: "", ten: " tens   " })
  end

  def test_number_to_human_with_custom_format
    assert_equal "123 times Thousand", 123456.to_fs(:human, format: "%n times %u")
    volume = { unit: "ml", thousand: "lt", million: "m3" }
    assert_equal "123.lt", 123456.to_fs(:human, units: volume, format: "%n.%u")
  end

  def test_to_fs__injected_on_proper_types
    assert_equal "1.23 Thousand", 1230.to_fs(:human)
    assert_equal "1.23 Thousand", Float(1230).to_fs(:human)
    assert_equal "100000 Quadrillion", (100**10).to_fs(:human)
    assert_equal "1 Million", BigDecimal("1000010").to_fs(:human)
  end

  def test_to_fs_with_invalid_formatter
    assert_equal "123", 123.to_fs(:invalid)
    assert_equal "123", 123.to_formatted_s(:invalid)
    assert_equal "2.5", 2.5.to_fs(:invalid)
    assert_equal "100000000000000000000", (100**10).to_fs(:invalid)
    assert_equal "1000010.0", BigDecimal("1000010").to_fs(:invalid)
  end

  def test_default_to_fs
    assert_equal "123", 123.to_s
    assert_equal "123", 123.to_fs
    assert_equal "123", 123.to_formatted_s
    assert_equal "1111011", 123.to_s(2)
    assert_equal "1111011", 123.to_fs(2)

    assert_equal "2.5", 2.5.to_s
    assert_equal "2.5", 2.5.to_fs

    assert_equal "100000000000000000000", (100**10).to_s
    assert_equal "100000000000000000000", (100**10).to_fs
    assert_equal "1010110101111000111010111100010110101100011000100000000000000000000", (100**10).to_s(2)
    assert_equal "1010110101111000111010111100010110101100011000100000000000000000000", (100**10).to_fs(2)

    assert_equal "1000010.0", BigDecimal("1000010").to_s
    assert_equal "1000010.0", BigDecimal("1000010").to_fs

    assert_equal "0.10000 1", BigDecimal("0.100001").to_s("5F")
    assert_equal "0.10000 1", BigDecimal("0.100001").to_fs("5F")

    assert_raises TypeError do
      1.to_s({})
    end
    assert_raises TypeError do
      1.to_fs({})
    end
  end
end
