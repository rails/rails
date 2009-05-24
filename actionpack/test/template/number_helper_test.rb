require 'abstract_unit'

class NumberHelperTest < ActionView::TestCase
  tests ActionView::Helpers::NumberHelper

  def test_number_to_phone
    assert_equal("555-1234", number_to_phone(5551234))
    assert_equal("800-555-1212", number_to_phone(8005551212))
    assert_equal("(800) 555-1212", number_to_phone(8005551212, {:area_code => true}))
    assert_equal("800 555 1212", number_to_phone(8005551212, {:delimiter => " "}))
    assert_equal("(800) 555-1212 x 123", number_to_phone(8005551212, {:area_code => true, :extension => 123}))
    assert_equal("800-555-1212", number_to_phone(8005551212, :extension => "  "))
    assert_equal("800-555-1212", number_to_phone("8005551212"))
    assert_equal("+1-800-555-1212", number_to_phone(8005551212, :country_code => 1))
    assert_equal("+18005551212", number_to_phone(8005551212, :country_code => 1, :delimiter => ''))
    assert_equal("22-555-1212", number_to_phone(225551212))
    assert_equal("+45-22-555-1212", number_to_phone(225551212, :country_code => 45))
    assert_equal("x", number_to_phone("x"))
    assert_nil number_to_phone(nil)
  end

  def test_number_to_currency
    assert_equal("$1,234,567,890.50", number_to_currency(1234567890.50))
    assert_equal("$1,234,567,890.51", number_to_currency(1234567890.506))
    assert_equal("$1,234,567,892", number_to_currency(1234567891.50, {:precision => 0}))
    assert_equal("$1,234,567,890.5", number_to_currency(1234567890.50, {:precision => 1}))
    assert_equal("&pound;1234567890,50", number_to_currency(1234567890.50, {:unit => "&pound;", :separator => ",", :delimiter => ""}))
    assert_equal("$1,234,567,890.50", number_to_currency("1234567890.50"))
    assert_equal("1,234,567,890.50 K&#269;", number_to_currency("1234567890.50", {:unit => "K&#269;", :format => "%n %u"}))
    #assert_equal("$x.", number_to_currency("x")) # fails due to API consolidation
    assert_equal("$x", number_to_currency("x"))
    assert_nil number_to_currency(nil)
  end

  def test_number_to_percentage
    assert_equal("100.000%", number_to_percentage(100))
    assert_equal("100%", number_to_percentage(100, {:precision => 0}))
    assert_equal("302.06%", number_to_percentage(302.0574, {:precision => 2}))
    assert_equal("100.000%", number_to_percentage("100"))
    assert_equal("1000.000%", number_to_percentage("1000"))
    assert_equal("x%", number_to_percentage("x"))
    assert_equal("1.000,000%", number_to_percentage(1000, :delimiter => '.', :separator => ','))
    assert_nil number_to_percentage(nil)
  end

  def test_number_with_delimiter
    assert_equal("12,345,678", number_with_delimiter(12345678))
    assert_equal("0", number_with_delimiter(0))
    assert_equal("123", number_with_delimiter(123))
    assert_equal("123,456", number_with_delimiter(123456))
    assert_equal("123,456.78", number_with_delimiter(123456.78))
    assert_equal("123,456.789", number_with_delimiter(123456.789))
    assert_equal("123,456.78901", number_with_delimiter(123456.78901))
    assert_equal("123,456,789.78901", number_with_delimiter(123456789.78901))
    assert_equal("0.78901", number_with_delimiter(0.78901))
    assert_equal("123,456.78", number_with_delimiter("123456.78"))
    assert_equal("x", number_with_delimiter("x"))
    assert_nil number_with_delimiter(nil)
  end

  def test_number_with_delimiter_with_options_hash
    assert_equal '12 345 678', number_with_delimiter(12345678, :delimiter => ' ')
    assert_equal '12,345,678-05', number_with_delimiter(12345678.05, :separator => '-')
    assert_equal '12.345.678,05', number_with_delimiter(12345678.05, :separator => ',', :delimiter => '.')
    assert_equal '12.345.678,05', number_with_delimiter(12345678.05, :delimiter => '.', :separator => ',')
  end

  def test_number_with_precision
    assert_equal("111.235", number_with_precision(111.2346))
    assert_equal("31.83", number_with_precision(31.825, :precision => 2))
    assert_equal("111.23", number_with_precision(111.2346, :precision => 2))
    assert_equal("111.00", number_with_precision(111, :precision => 2))
    assert_equal("111.235", number_with_precision("111.2346"))
    assert_equal("31.83", number_with_precision("31.825", :precision => 2))
    assert_equal("112", number_with_precision(111.50, :precision => 0))
    assert_equal("1234567892", number_with_precision(1234567891.50, :precision => 0))

    # Return non-numeric params unchanged.
    assert_equal("x", number_with_precision("x"))
    assert_nil number_with_precision(nil)
  end

  def test_number_with_precision_with_custom_delimiter_and_separator
    assert_equal '31,83',       number_with_precision(31.825, :precision => 2, :separator => ',')
    assert_equal '1.231,83',    number_with_precision(1231.825, :precision => 2, :separator => ',', :delimiter => '.')
  end

  def test_number_to_human_size
    assert_equal '0 Bytes',   number_to_human_size(0)
    assert_equal '1 Byte',    number_to_human_size(1)
    assert_equal '3 Bytes',   number_to_human_size(3.14159265)
    assert_equal '123 Bytes', number_to_human_size(123.0)
    assert_equal '123 Bytes', number_to_human_size(123)
    assert_equal '1.2 KB',    number_to_human_size(1234)
    assert_equal '12.1 KB',   number_to_human_size(12345)
    assert_equal '1.2 MB',    number_to_human_size(1234567)
    assert_equal '1.1 GB',    number_to_human_size(1234567890)
    assert_equal '1.1 TB',    number_to_human_size(1234567890123)
    assert_equal '1025 TB',   number_to_human_size(1025.terabytes)
    assert_equal '444 KB',    number_to_human_size(444.kilobytes)
    assert_equal '1023 MB',   number_to_human_size(1023.megabytes)
    assert_equal '3 TB',      number_to_human_size(3.terabytes)
    assert_equal '1.18 MB',   number_to_human_size(1234567, :precision => 2)
    assert_equal '3 Bytes',   number_to_human_size(3.14159265, :precision => 4)
    assert_equal("123 Bytes", number_to_human_size("123"))
    assert_equal '1.01 KB',   number_to_human_size(1.0123.kilobytes, :precision => 2)
    assert_equal '1.01 KB',   number_to_human_size(1.0100.kilobytes, :precision => 4)
    assert_equal '10 KB',   number_to_human_size(10.000.kilobytes, :precision => 4)
    assert_equal '1 Byte',   number_to_human_size(1.1)
    assert_equal '10 Bytes', number_to_human_size(10)
    #assert_nil number_to_human_size('x') # fails due to API consolidation
    assert_nil number_to_human_size(nil)
  end

  def test_number_to_human_size_with_options_hash
    assert_equal '1.18 MB',   number_to_human_size(1234567, :precision => 2)
    assert_equal '3 Bytes',   number_to_human_size(3.14159265, :precision => 4)
    assert_equal '1.01 KB',   number_to_human_size(1.0123.kilobytes, :precision => 2)
    assert_equal '1.01 KB',   number_to_human_size(1.0100.kilobytes, :precision => 4)
    assert_equal '10 KB',     number_to_human_size(10.000.kilobytes, :precision => 4)
    assert_equal '1 TB', number_to_human_size(1234567890123, :precision => 0)
    assert_equal '500 MB', number_to_human_size(524288000, :precision=>0)
    assert_equal '40 KB', number_to_human_size(41010, :precision => 0)
    assert_equal '40 KB', number_to_human_size(41100, :precision => 0)
  end

  def test_number_to_human_size_with_custom_delimiter_and_separator
    assert_equal '1,01 KB',     number_to_human_size(1.0123.kilobytes, :precision => 2, :separator => ',')
    assert_equal '1,01 KB',     number_to_human_size(1.0100.kilobytes, :precision => 4, :separator => ',')
    assert_equal '1.000,1 TB',  number_to_human_size(1000.1.terabytes, :delimiter => '.', :separator => ',')
  end
end
