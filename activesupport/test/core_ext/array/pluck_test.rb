require 'active_support/core_ext/array'

class PluckTest < ActiveSupport::TestCase
  def test_pluck_one_key
    x = [{ a: 1, b: 2 }, { a: 10, b: 20 }]
    assert_equal([1, 10], x.pluck(:a))
  end

  def test_pluck_many_keys
    x = [{ a: 1, b: 2 }, { a: 10, b: 20 }]
    assert_equal([[1, 2], [10, 20]], x.pluck(:a, :b))
  end
end
