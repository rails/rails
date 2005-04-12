require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/number_helper'
require File.dirname(__FILE__) + '/../../../activesupport/lib/active_support/core_ext/numeric'  # for human_size

class NumberHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::NumberHelper
  
  def test_number_to_human_size
    assert_equal("0 Bytes", number_to_human_size(0))
    assert_equal("3 Bytes", number_to_human_size(3.14159265))
    assert_equal("123 Bytes", number_to_human_size(123.0))
    assert_equal("123 Bytes", number_to_human_size(123))
    assert_equal("1.2 KB", number_to_human_size(1234))
    assert_equal("12.1 KB", number_to_human_size(12345))
    assert_equal("1.2 MB", number_to_human_size(1234567))
    assert_equal("1.1 GB", number_to_human_size(1234567890))
    assert_equal("1.1 TB", number_to_human_size(1234567890123))
    assert_equal("444.0 KB", number_to_human_size(444.kilobytes))
    assert_equal("1023.0 MB", number_to_human_size(1023.megabytes))
    assert_equal("3.0 TB", number_to_human_size(3.terabytes))
    assert_nil number_to_human_size('x')
  end
end
