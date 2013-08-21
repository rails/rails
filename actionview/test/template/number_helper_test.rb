require "abstract_unit"

class NumberHelperTest < ActionView::TestCase
  tests ActionView::Helpers::NumberHelper

  def test_number_to_phone
    assert_equal nil, number_to_phone(nil)
    assert_equal "555-1234", number_to_phone(5551234)
    assert_equal "(800) 555-1212 x 123", number_to_phone(8005551212, area_code: true, extension: 123)
    assert_equal "+18005551212", number_to_phone(8005551212, country_code: 1, delimiter: "")
  end

  def test_number_to_currency
    assert_equal nil, number_to_currency(nil)
    assert_equal "$1,234,567,890.50", number_to_currency(1234567890.50)
    assert_equal "$1,234,567,892", number_to_currency(1234567891.50, precision: 0)
    assert_equal "1,234,567,890.50 - K&#269;", number_to_currency("-1234567890.50", unit: "K&#269;", format: "%n %u", negative_format: "%n - %u")
  end

  def test_number_to_percentage
    assert_equal nil, number_to_percentage(nil)
    assert_equal "100.000%", number_to_percentage(100)
    assert_equal "100%", number_to_percentage(100, precision: 0)
    assert_equal "123.4%", number_to_percentage(123.400, precision: 3, strip_insignificant_zeros: true)
    assert_equal "1.000,000%", number_to_percentage(1000, delimiter: ".", separator: ",")
  end

  def test_number_with_delimiter
    assert_equal nil, number_with_delimiter(nil)
    assert_equal "12,345,678", number_with_delimiter(12345678)
    assert_equal "0", number_with_delimiter(0)
  end

  def test_number_with_precision
    assert_equal nil, number_with_precision(nil)
    assert_equal "-111.235", number_with_precision(-111.2346)
    assert_equal "111.00", number_with_precision(111, precision: 2)
    assert_equal "0.00100", number_with_precision(0.001, precision: 5)
  end

  def test_number_to_human_size
    assert_equal nil, number_to_human_size(nil)
    assert_equal "3 Bytes", number_to_human_size(3.14159265)
    assert_equal "1.2 MB", number_to_human_size(1234567, precision: 2)
  end

  def test_number_to_human
    assert_equal nil,   number_to_human(nil)
    assert_equal "0",   number_to_human(0)
    assert_equal "1.23 Thousand", number_to_human(1234)
    assert_equal "489.0 Thousand", number_to_human(489000, precision: 4, strip_insignificant_zeros: false)
  end

  def test_number_helpers_escape_delimiter_and_separator
    assert_equal "111&lt;script&gt;&lt;/script&gt;111&lt;script&gt;&lt;/script&gt;1111", number_to_phone(1111111111, delimiter: "<script></script>")

    assert_equal "$1&lt;script&gt;&lt;/script&gt;01", number_to_currency(1.01, separator: "<script></script>")
    assert_equal "$1&lt;script&gt;&lt;/script&gt;000.00", number_to_currency(1000, delimiter: "<script></script>")

    assert_equal "1&lt;script&gt;&lt;/script&gt;010%", number_to_percentage(1.01, separator: "<script></script>")
    assert_equal "1&lt;script&gt;&lt;/script&gt;000.000%", number_to_percentage(1000, delimiter: "<script></script>")

    assert_equal "1&lt;script&gt;&lt;/script&gt;01", number_with_delimiter(1.01, separator: "<script></script>")
    assert_equal "1&lt;script&gt;&lt;/script&gt;000", number_with_delimiter(1000, delimiter: "<script></script>")

    assert_equal "1&lt;script&gt;&lt;/script&gt;010", number_with_precision(1.01, separator: "<script></script>")
    assert_equal "1&lt;script&gt;&lt;/script&gt;000.000", number_with_precision(1000, delimiter: "<script></script>")

    assert_equal "9&lt;script&gt;&lt;/script&gt;86 KB", number_to_human_size(10100, separator: "<script></script>")

    assert_equal "1&lt;script&gt;&lt;/script&gt;01", number_to_human(1.01, separator: "<script></script>")
    assert_equal "100&lt;script&gt;&lt;/script&gt;000 Quadrillion", number_to_human(10**20, delimiter: "<script></script>")
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

    assert number_with_precision(1, strip_insignificant_zeros: false).html_safe?
    assert number_with_precision(1, strip_insignificant_zeros: true).html_safe?
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
      number_to_human("x", raise: true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_to_human_size("x", raise: true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_with_precision("x", raise: true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_to_currency("x", raise: true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_to_percentage("x", raise: true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_with_delimiter("x", raise: true)
    end
    assert_equal "x", exception.number

    exception = assert_raise InvalidNumberError do
      number_to_phone("x", raise: true)
    end
    assert_equal "x", exception.number
  end
end
