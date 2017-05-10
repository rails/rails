require 'abstract_unit'
require 'active_support/core_ext/array/clear'

class ClearTest < ActiveSupport::TestCase
  def test_clear!
    array = %w( a b c d )
    assert_equal %w( a b c d ), array.clear!
    assert_equal [], array
  end

  def test_clear?
    assert_equal false, %w( a b c d ).clear?
    assert_equal true, %w().clear?
  end
end
