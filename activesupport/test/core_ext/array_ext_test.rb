require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/array'

class ArrayExtToParamTests < Test::Unit::TestCase
  def test_string_array
    assert_equal '', %w().to_param
    assert_equal 'hello/world', %w(hello world).to_param
    assert_equal 'hello/10', %w(hello 10).to_param
  end
  
  def test_number_array
    assert_equal '10/20', [10, 20].to_param
  end
end
