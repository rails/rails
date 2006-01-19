require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/number_helper'
require File.dirname(__FILE__) + '/../../../activesupport/lib/active_support/core_ext/hash' # for stringify_keys
require File.dirname(__FILE__) + '/../../../activesupport/lib/active_support/core_ext/numeric'  # for human_size

class NumberHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::NumberHelper
  include ActiveSupport::CoreExtensions::Hash

  def test_number_to_phone
    assert_equal("123-555-1234", number_to_phone(1235551234))
    assert_equal("(123) 555-1234", number_to_phone(1235551234, {:area_code => true}))
    assert_equal("123 555 1234", number_to_phone(1235551234, {:delimiter => " "}))
    assert_equal("(123) 555-1234 x 555", number_to_phone(1235551234, {:area_code => true, :extension => 555}))
    assert_equal("123-555-1234", number_to_phone(1235551234, :extension => "   "))
  end

  def test_number_to_currency
    assert_equal("$1,234,567,890.50", number_to_currency(1234567890.50))
    assert_equal("$1,234,567,890.51", number_to_currency(1234567890.506))
    assert_equal("$1,234,567,890", number_to_currency(1234567890.50, {:precision => 0}))
    assert_equal("$1,234,567,890.5", number_to_currency(1234567890.50, {:precision => 1}))
    assert_equal("&pound;1234567890,50", number_to_currency(1234567890.50, {:unit => "&pound;", :separator => ",", :delimiter => ""}))
  end

  def test_number_to_percentage
    assert_equal("100.000%", number_to_percentage(100))
    assert_equal("100%", number_to_percentage(100, {:precision => 0}))
    assert_equal("302.06%", number_to_percentage(302.0574, {:precision => 2}))
  end

  def test_number_with_delimiter
    assert_equal("12,345,678", number_with_delimiter(12345678))
  end

  def test_number_to_human_size
    assert_equal '0 Bytes',   human_size(0)
    assert_equal '3 Bytes',   human_size(3.14159265)
    assert_equal '123 Bytes', human_size(123.0)
    assert_equal '123 Bytes', human_size(123)
    assert_equal '1.2 KB',    human_size(1234)
    assert_equal '12.1 KB',   human_size(12345)
    assert_equal '1.2 MB',    human_size(1234567)
    assert_equal '1.1 GB',    human_size(1234567890)
    assert_equal '1.1 TB',    human_size(1234567890123)
    assert_equal '444 KB',    human_size(444.kilobytes)
    assert_equal '1023 MB',   human_size(1023.megabytes)
    assert_equal '3 TB',      human_size(3.terabytes)
    assert_nil human_size('x')
    assert_nil human_size(nil)
  end

  def test_number_with_precision
    assert_equal("111.235", number_with_precision(111.2346))
  end
end
