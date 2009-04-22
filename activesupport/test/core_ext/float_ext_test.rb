require 'abstract_unit'
require 'active_support/core_ext/float/rounding'

class FloatExtRoundingTests < Test::Unit::TestCase
  def test_round_for_positive_number
    assert_equal 1,    1.4.round
    assert_equal 2,    1.6.round
    assert_equal 2,    1.6.round(0)
    assert_equal 1.4,  1.4.round(1)
    assert_equal 1.4,  1.4.round(3)
    assert_equal 1.5,  1.45.round(1)
    assert_equal 1.45, 1.445.round(2)
  end

  def test_round_for_negative_number
    assert_equal( -1,   -1.4.round )
    assert_equal( -2,   -1.6.round )
    assert_equal( -1.4, -1.4.round(1) )
    assert_equal( -1.5, -1.45.round(1) )
  end

  def test_round_with_negative_precision
    assert_equal 123460.0, 123456.0.round(-1)
    assert_equal 123500.0, 123456.0.round(-2)
  end
end
