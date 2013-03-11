# encoding: utf-8
require 'abstract_unit'
require 'active_support/core_ext/string'
require 'active_support/core_ext/string/boolean'

class BooleanExtTest < ActiveSupport::TestCase
  def test_true
    assert_equal true, "true".to_boolean
    assert_equal true, "t".to_boolean
    assert_equal true, "1".to_boolean
  end

  def test_false
    assert_equal false, "false".to_boolean
    assert_equal false, "f".to_boolean
    assert_equal false, "0".to_boolean
  end

  def test_raise_error
    assert_raise(ArgumentError) { "foo".to_boolean }
  end
end
