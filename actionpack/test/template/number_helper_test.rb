require 'abstract_unit'

class NumberHelperTest < ActionView::TestCase
  tests ActionView::Helpers::NumberHelper

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

  def test_number_to_phone
    assert_equal("555-1234", number_to_phone(5551234))
    assert_equal("800-555-1212", number_to_phone(8005551212))
    assert_equal("(800) 555-1212", number_to_phone(8005551212, {:area_code => true}))
    assert_equal("", number_to_phone("", {:area_code => true}))
    assert_equal("800 555 1212", number_to_phone(8005551212, {:delimiter => " "}))
    assert_equal("(800) 555-1212 x 123", number_to_phone(8005551212, {:area_code => true, :extension => 123}))
    assert_equal("800-555-1212", number_to_phone(8005551212, :extension => "  "))
    assert_equal("555.1212", number_to_phone(5551212, :delimiter => '.'))
    assert_equal("800-555-1212", number_to_phone("8005551212"))
    assert_equal("+1-800-555-1212", number_to_phone(8005551212, :country_code => 1))
    assert_equal("+18005551212", number_to_phone(8005551212, :country_code => 1, :delimiter => ''))
    assert_equal("22-555-1212", number_to_phone(225551212))
    assert_equal("+45-22-555-1212", number_to_phone(225551212, :country_code => 45))
    assert_equal '111&lt;script&gt;&lt;/script&gt;111&lt;script&gt;&lt;/script&gt;1111', number_to_phone(1111111111, :delimiter => "<script></script>")
  end

  def test_number_to_currency
    assert_equal("$1,234,567,890.50", number_to_currency(1234567890.50))
    assert_equal("$1,234,567,890.51", number_to_currency(1234567890.506))
    assert_equal("-$1,234,567,890.50", number_to_currency(-1234567890.50))
    assert_equal("-$ 1,234,567,890.50", number_to_currency(-1234567890.50, {:format => "%u %n"}))
    assert_equal("($1,234,567,890.50)", number_to_currency(-1234567890.50, {:negative_format => "(%u%n)"}))
    assert_equal("$1,234,567,892", number_to_currency(1234567891.50, {:precision => 0}))
    assert_equal("$1,234,567,890.5", number_to_currency(1234567890.50, {:precision => 1}))
    assert_equal("&pound;1234567890,50", number_to_currency(1234567890.50, {:unit => "&pound;", :separator => ",", :delimiter => ""}))
    assert_equal("$1,234,567,890.50", number_to_currency("1234567890.50"))
    assert_equal("1,234,567,890.50 K&#269;", number_to_currency("1234567890.50", {:unit => "K&#269;", :format => "%n %u"}))
    assert_equal("1,234,567,890.50 - K&#269;", number_to_currency("-1234567890.50", {:unit => "K&#269;", :format => "%n %u", :negative_format => "%n - %u"}))
    assert_equal '$1&lt;script&gt;&lt;/script&gt;01', number_to_currency(1.01, :separator => "<script></script>")
    assert_equal '$1&lt;script&gt;&lt;/script&gt;000.00', number_to_currency(1000, :delimiter => "<script></script>")
  end

  def test_number_to_percentage
    assert_equal("100.000%", number_to_percentage(100))
    assert_equal("100%", number_to_percentage(100, {:precision => 0}))
    assert_equal("302.06%", number_to_percentage(302.0574, {:precision => 2}))
    assert_equal("100.000%", number_to_percentage("100"))
    assert_equal("1000.000%", number_to_percentage("1000"))
    assert_equal("123.4%", number_to_percentage(123.400, :precision => 3, :strip_insignificant_zeros => true))
    assert_equal("1.000,000%", number_to_percentage(1000, :delimiter => '.', :separator => ','))
    assert_equal("1000.000  %", number_to_percentage(1000, :format => "%n  %"))
    assert_equal '1&lt;script&gt;&lt;/script&gt;010%', number_to_percentage(1.01, :separator => "<script></script>")
    assert_equal '1&lt;script&gt;&lt;/script&gt;000.000%', number_to_percentage(1000, :delimiter => "<script></script>")
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
  end

  def test_number_with_delimiter_with_options_hash
    assert_equal '12 345 678', number_with_delimiter(12345678, :delimiter => ' ')
    assert_equal '12,345,678-05', number_with_delimiter(12345678.05, :separator => '-')
    assert_equal '12.345.678,05', number_with_delimiter(12345678.05, :separator => ',', :delimiter => '.')
    assert_equal '12.345.678,05', number_with_delimiter(12345678.05, :delimiter => '.', :separator => ',')
    assert_equal '1&lt;script&gt;&lt;/script&gt;01', number_with_delimiter(1.01, :separator => "<script></script>")
    assert_equal '1&lt;script&gt;&lt;/script&gt;000', number_with_delimiter(1000, :delimiter => "<script></script>")
  end

  def test_number_with_precision
    assert_equal("-111.235", number_with_precision(-111.2346))
    assert_equal("111.235", number_with_precision(111.2346))
    assert_equal("31.83", number_with_precision(31.825, :precision => 2))
    assert_equal("111.23", number_with_precision(111.2346, :precision => 2))
    assert_equal("111.00", number_with_precision(111, :precision => 2))
    assert_equal("111.235", number_with_precision("111.2346"))
    assert_equal("31.83", number_with_precision("31.825", :precision => 2))
    assert_equal("3268", number_with_precision((32.6751 * 100.00), :precision => 0))
    assert_equal("112", number_with_precision(111.50, :precision => 0))
    assert_equal("1234567892", number_with_precision(1234567891.50, :precision => 0))
    assert_equal("0", number_with_precision(0, :precision => 0))
    assert_equal("0.00100", number_with_precision(0.001, :precision => 5))
    assert_equal("0.001", number_with_precision(0.00111, :precision => 3))
    assert_equal("10.00", number_with_precision(9.995, :precision => 2))
    assert_equal("11.00", number_with_precision(10.995, :precision => 2))
    assert_equal("0.00", number_with_precision(-0.001, :precision => 2))
  end

  def test_number_with_precision_with_custom_delimiter_and_separator
    assert_equal '31,83',       number_with_precision(31.825, :precision => 2, :separator => ',')
    assert_equal '1.231,83',    number_with_precision(1231.825, :precision => 2, :separator => ',', :delimiter => '.')
    assert_equal '1&lt;script&gt;&lt;/script&gt;010', number_with_precision(1.01, :separator => "<script></script>")
    assert_equal '1&lt;script&gt;&lt;/script&gt;000.000', number_with_precision(1000, :delimiter => "<script></script>")
  end

  def test_number_with_precision_with_significant_digits
    assert_equal "124000", number_with_precision(123987, :precision => 3, :significant => true)
    assert_equal "120000000", number_with_precision(123987876, :precision => 2, :significant => true )
    assert_equal "40000", number_with_precision("43523", :precision => 1, :significant => true )
    assert_equal "9775", number_with_precision(9775, :precision => 4, :significant => true )
    assert_equal "5.4", number_with_precision(5.3923, :precision => 2, :significant => true )
    assert_equal "5", number_with_precision(5.3923, :precision => 1, :significant => true )
    assert_equal "1", number_with_precision(1.232, :precision => 1, :significant => true )
    assert_equal "7", number_with_precision(7, :precision => 1, :significant => true )
    assert_equal "1", number_with_precision(1, :precision => 1, :significant => true )
    assert_equal "53", number_with_precision(52.7923, :precision => 2, :significant => true )
    assert_equal "9775.00", number_with_precision(9775, :precision => 6, :significant => true )
    assert_equal "5.392900", number_with_precision(5.3929, :precision => 7, :significant => true )
    assert_equal "0.0", number_with_precision(0, :precision => 2, :significant => true )
    assert_equal "0", number_with_precision(0, :precision => 1, :significant => true )
    assert_equal "0.0001", number_with_precision(0.0001, :precision => 1, :significant => true )
    assert_equal "0.000100", number_with_precision(0.0001, :precision => 3, :significant => true )
    assert_equal "0.0001", number_with_precision(0.0001111, :precision => 1, :significant => true )
    assert_equal "10.0", number_with_precision(9.995, :precision => 3, :significant => true)
    assert_equal "9.99", number_with_precision(9.994, :precision => 3, :significant => true)
    assert_equal "11.0", number_with_precision(10.995, :precision => 3, :significant => true)
  end

  def test_number_with_precision_with_strip_insignificant_zeros
    assert_equal "9775.43", number_with_precision(9775.43, :precision => 4, :strip_insignificant_zeros => true )
    assert_equal "9775.2", number_with_precision(9775.2, :precision => 6, :significant => true, :strip_insignificant_zeros => true )
    assert_equal "0", number_with_precision(0, :precision => 6, :significant => true, :strip_insignificant_zeros => true )
  end

  def test_number_with_precision_with_significant_true_and_zero_precision
    # Zero precision with significant is a mistake (would always return zero),
    # so we treat it as if significant was false (increases backwards compatibility for number_to_human_size)
    assert_equal "124", number_with_precision(123.987, :precision => 0, :significant => true)
    assert_equal "12", number_with_precision(12, :precision => 0, :significant => true )
    assert_equal "12", number_with_precision("12.3", :precision => 0, :significant => true )
  end

  def test_number_to_human_size
    assert_equal '0 Bytes',   number_to_human_size(0)
    assert_equal '1 Byte',    number_to_human_size(1)
    assert_equal '3 Bytes',   number_to_human_size(3.14159265)
    assert_equal '123 Bytes', number_to_human_size(123.0)
    assert_equal '123 Bytes', number_to_human_size(123)
    assert_equal '1.21 KB',    number_to_human_size(1234)
    assert_equal '12.1 KB',   number_to_human_size(12345)
    assert_equal '1.18 MB',    number_to_human_size(1234567)
    assert_equal '1.15 GB',    number_to_human_size(1234567890)
    assert_equal '1.12 TB',    number_to_human_size(1234567890123)
    assert_equal '1030 TB',   number_to_human_size(terabytes(1026))
    assert_equal '444 KB',    number_to_human_size(kilobytes(444))
    assert_equal '1020 MB',   number_to_human_size(megabytes(1023))
    assert_equal '3 TB',      number_to_human_size(terabytes(3))
    assert_equal '1.2 MB',   number_to_human_size(1234567, :precision => 2)
    assert_equal '3 Bytes',   number_to_human_size(3.14159265, :precision => 4)
    assert_equal '123 Bytes', number_to_human_size('123')
    assert_equal '1 KB',   number_to_human_size(kilobytes(1.0123), :precision => 2)
    assert_equal '1.01 KB',   number_to_human_size(kilobytes(1.0100), :precision => 4)
    assert_equal '10 KB',   number_to_human_size(kilobytes(10.000), :precision => 4)
    assert_equal '1 Byte',   number_to_human_size(1.1)
    assert_equal '10 Bytes', number_to_human_size(10)
  end

  def test_number_to_human_size_with_si_prefix
    assert_equal '3 Bytes',    number_to_human_size(3.14159265, :prefix => :si)
    assert_equal '123 Bytes',  number_to_human_size(123.0, :prefix => :si)
    assert_equal '123 Bytes',  number_to_human_size(123, :prefix => :si)
    assert_equal '1.23 KB',    number_to_human_size(1234, :prefix => :si)
    assert_equal '12.3 KB',    number_to_human_size(12345, :prefix => :si)
    assert_equal '1.23 MB',    number_to_human_size(1234567, :prefix => :si)
    assert_equal '1.23 GB',    number_to_human_size(1234567890, :prefix => :si)
    assert_equal '1.23 TB',    number_to_human_size(1234567890123, :prefix => :si)
  end

  def test_number_to_human_size_with_options_hash
    assert_equal '1.2 MB',   number_to_human_size(1234567, :precision => 2)
    assert_equal '3 Bytes',   number_to_human_size(3.14159265, :precision => 4)
    assert_equal '1 KB',   number_to_human_size(kilobytes(1.0123), :precision => 2)
    assert_equal '1.01 KB',   number_to_human_size(kilobytes(1.0100), :precision => 4)
    assert_equal '10 KB',     number_to_human_size(kilobytes(10.000), :precision => 4)
    assert_equal '1 TB', number_to_human_size(1234567890123, :precision => 1)
    assert_equal '500 MB', number_to_human_size(524288000, :precision=>3)
    assert_equal '10 MB', number_to_human_size(9961472, :precision=>0)
    assert_equal '40 KB', number_to_human_size(41010, :precision => 1)
    assert_equal '40 KB', number_to_human_size(41100, :precision => 2)
    assert_equal '1.0 KB',   number_to_human_size(kilobytes(1.0123), :precision => 2, :strip_insignificant_zeros => false)
    assert_equal '1.012 KB',   number_to_human_size(kilobytes(1.0123), :precision => 3, :significant => false)
    assert_equal '1 KB',   number_to_human_size(kilobytes(1.0123), :precision => 0, :significant => true) #ignores significant it precision is 0
    assert_equal '9&lt;script&gt;&lt;/script&gt;86 KB', number_to_human_size(10100, :separator => "<script></script>")
  end

  def test_number_to_human_size_with_custom_delimiter_and_separator
    assert_equal '1,01 KB',     number_to_human_size(kilobytes(1.0123), :precision => 3, :separator => ',')
    assert_equal '1,01 KB',     number_to_human_size(kilobytes(1.0100), :precision => 4, :separator => ',')
    assert_equal '1.000,1 TB',  number_to_human_size(terabytes(1000.1), :precision => 5, :delimiter => '.', :separator => ',')
  end

  def test_number_to_human
    assert_equal '-123', number_to_human(-123)
    assert_equal '-0.5', number_to_human(-0.5)
    assert_equal '0',   number_to_human(0)
    assert_equal '0.5', number_to_human(0.5)
    assert_equal '123', number_to_human(123)
    assert_equal '1.23 Thousand', number_to_human(1234)
    assert_equal '12.3 Thousand', number_to_human(12345)
    assert_equal '1.23 Million', number_to_human(1234567)
    assert_equal '1.23 Billion', number_to_human(1234567890)
    assert_equal '1.23 Trillion', number_to_human(1234567890123)
    assert_equal '1.23 Quadrillion', number_to_human(1234567890123456)
    assert_equal '1230 Quadrillion', number_to_human(1234567890123456789)
    assert_equal '490 Thousand', number_to_human(489939, :precision => 2)
    assert_equal '489.9 Thousand', number_to_human(489939, :precision => 4)
    assert_equal '489 Thousand', number_to_human(489000, :precision => 4)
    assert_equal '489.0 Thousand', number_to_human(489000, :precision => 4, :strip_insignificant_zeros => false)
    assert_equal '1.2346 Million', number_to_human(1234567, :precision => 4, :significant => false)
    assert_equal '1,2 Million', number_to_human(1234567, :precision => 1, :significant => false, :separator => ',')
    assert_equal '1 Million', number_to_human(1234567, :precision => 0, :significant => true, :separator => ',') #significant forced to false
  end

  def test_number_to_human_with_custom_units
    #Only integers
    volume = {:unit => "ml", :thousand => "lt", :million => "m3"}
    assert_equal '123 lt', number_to_human(123456, :units => volume)
    assert_equal '12 ml', number_to_human(12, :units => volume)
    assert_equal '1.23 m3', number_to_human(1234567, :units => volume)

    #Including fractionals
    distance = {:mili => "mm", :centi => "cm", :deci => "dm", :unit => "m", :ten => "dam", :hundred => "hm", :thousand => "km"}
    assert_equal '1.23 mm', number_to_human(0.00123, :units => distance)
    assert_equal '1.23 cm', number_to_human(0.0123, :units => distance)
    assert_equal '1.23 dm', number_to_human(0.123, :units => distance)
    assert_equal '1.23 m', number_to_human(1.23, :units => distance)
    assert_equal '1.23 dam', number_to_human(12.3, :units => distance)
    assert_equal '1.23 hm', number_to_human(123, :units => distance)
    assert_equal '1.23 km', number_to_human(1230, :units => distance)
    assert_equal '1.23 km', number_to_human(1230, :units => distance)
    assert_equal '1.23 km', number_to_human(1230, :units => distance)
    assert_equal '12.3 km', number_to_human(12300, :units => distance)

    #The quantifiers don't need to be a continuous sequence
    gangster = {:hundred => "hundred bucks", :million => "thousand quids"}
    assert_equal '1 hundred bucks', number_to_human(100, :units => gangster)
    assert_equal '25 hundred bucks', number_to_human(2500, :units => gangster)
    assert_equal '25 thousand quids', number_to_human(25000000, :units => gangster)
    assert_equal '12300 thousand quids', number_to_human(12345000000, :units => gangster)

    #Spaces are stripped from the resulting string
    assert_equal '4', number_to_human(4, :units => {:unit => "", :ten => 'tens '})
    assert_equal '4.5  tens', number_to_human(45, :units => {:unit => "", :ten => ' tens   '})

    assert_equal '1&lt;script&gt;&lt;/script&gt;01', number_to_human(1.01, :separator => "<script></script>")
    assert_equal '100&lt;script&gt;&lt;/script&gt;000 Quadrillion', number_to_human(10**20, :delimiter => "<script></script>")
  end

  def test_number_to_human_with_custom_units_that_are_missing_the_needed_key
    assert_equal '123', number_to_human(123, :units => {:thousand => 'k'})
    assert_equal '123', number_to_human(123, :units => {})
  end

  def test_number_to_human_with_custom_format
    assert_equal '123 times Thousand', number_to_human(123456, :format => "%n times %u")
    volume = {:unit => "ml", :thousand => "lt", :million => "m3"}
    assert_equal '123.lt', number_to_human(123456, :units => volume, :format => "%n.%u")
  end

  def test_number_helpers_should_return_nil_when_given_nil
    assert_nil number_to_phone(nil)
    assert_nil number_to_currency(nil)
    assert_nil number_to_percentage(nil)
    assert_nil number_with_delimiter(nil)
    assert_nil number_with_precision(nil)
    assert_nil number_to_human_size(nil)
    assert_nil number_to_human(nil)
  end

  def test_number_helpers_do_not_mutate_options_hash
    options = { 'raise' => true }

    number_to_phone(1, options)
    assert_equal({ 'raise' => true }, options)

    number_to_currency(1, options)
    assert_equal({ 'raise' => true }, options)

    number_to_percentage(1, options)
    assert_equal({ 'raise' => true }, options)

    number_with_delimiter(1, options)
    assert_equal({ 'raise' => true }, options)

    number_with_precision(1, options)
    assert_equal({ 'raise' => true }, options)

    number_to_human_size(1, options)
    assert_equal({ 'raise' => true }, options)

    number_to_human(1, options)
    assert_equal({ 'raise' => true }, options)
  end

  def test_number_helpers_should_return_non_numeric_param_unchanged
    assert_equal("+1-x x 123", number_to_phone("x", :country_code => 1, :extension => 123))
    assert_equal("x", number_to_phone("x"))
    assert_equal("$x.", number_to_currency("x."))
    assert_equal("$x", number_to_currency("x"))
    assert_equal("x%", number_to_percentage("x"))
    assert_equal("x", number_with_delimiter("x"))
    assert_equal("x.", number_with_precision("x."))
    assert_equal("x", number_with_precision("x"))
    assert_equal "x", number_to_human_size('x')
    assert_equal "x", number_to_human('x')
  end

  def test_number_helpers_outputs_are_html_safe
    assert number_to_human(1).html_safe?
    assert !number_to_human("<script></script>").html_safe?
    assert number_to_human("asdf".html_safe).html_safe?
    assert number_to_human("1".html_safe).html_safe?

    assert number_to_human_size(1).html_safe?
    assert number_to_human_size(1000000).html_safe?
    assert !number_to_human_size("<script></script>").html_safe?
    assert number_to_human_size("asdf".html_safe).html_safe?
    assert number_to_human_size("1".html_safe).html_safe?

    assert number_with_precision(1, :strip_insignificant_zeros => false).html_safe?
    assert number_with_precision(1, :strip_insignificant_zeros => true).html_safe?
    assert !number_with_precision("<script></script>").html_safe?
    assert number_with_precision("asdf".html_safe).html_safe?
    assert number_with_precision("1".html_safe).html_safe?

    assert number_to_currency(1).html_safe?
    assert !number_to_currency("<script></script>").html_safe?
    assert number_to_currency("asdf".html_safe).html_safe?
    assert number_to_currency("1".html_safe).html_safe?

    assert number_to_percentage(1).html_safe?
    assert !number_to_percentage("<script></script>").html_safe?
    assert number_to_percentage("asdf".html_safe).html_safe?
    assert number_to_percentage("1".html_safe).html_safe?

    assert number_to_phone(1).html_safe?
    assert_equal "&lt;script&gt;&lt;/script&gt;", number_to_phone("<script></script>")
    assert number_to_phone("<script></script>").html_safe?
    assert number_to_phone("asdf".html_safe).html_safe?
    assert number_to_phone("1".html_safe).html_safe?

    assert number_with_delimiter(1).html_safe?
    assert !number_with_delimiter("<script></script>").html_safe?
    assert number_with_delimiter("asdf".html_safe).html_safe?
    assert number_with_delimiter("1".html_safe).html_safe?
  end

  def test_number_helpers_should_raise_error_if_invalid_when_specified
    exception = assert_raise InvalidNumberError do
      number_to_human("x", :raise => true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_to_human_size("x", :raise => true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_with_precision("x", :raise => true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_to_currency("x", :raise => true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_to_percentage("x", :raise => true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_with_delimiter("x", :raise => true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_to_phone("x", :raise => true)
    end
    assert_equal "x", exception.number
  end
end
