require 'abstract_unit'
require 'active_support/core_ext/object/to_s'

class ToParamTest < ActiveSupport::TestCase
  def test_nil_with_args
    assert_equal nil.to_s(:foo), ''
  end

  def test_nil_without_args
    assert_equal nil.to_s, ''
  end
end
