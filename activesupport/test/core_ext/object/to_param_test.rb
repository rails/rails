require 'abstract_unit'
require 'active_support/core_ext/object/to_param'

class ToParamTest < ActiveSupport::TestCase
  def test_object
    foo = Object.new
    def foo.to_s; 'foo' end
    assert_equal 'foo', foo.to_param
  end

  def test_nil
    assert_nil nil.to_param
  end

  def test_boolean
    assert_equal true, true.to_param
    assert_equal false, false.to_param
  end
end
