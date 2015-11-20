require 'abstract_unit'
require 'active_support/core_ext/comparable'

class ComparableExtClampTest < ActiveSupport::TestCase
  def test_self_in_range
    assert_equal 5.clamp(3, 7), 5
  end

  def test_self_below_range
    assert_equal 1.clamp(2, 8), 2
  end

  def test_self_above_range
    assert_equal 7.clamp(3, 4), 4
  end

  def test_float_between_ints
    assert_equal (4.5).clamp(3, 6), 4.5
  end

  def test_float_above_ints
    assert_equal (6.5).clamp(1, 3), 3
  end

  def test_float_below_ints
    assert_equal (6.5).clamp(11, 99), 11
  end

  def test_character_range
    assert_equal 'c'.clamp('a', 'e'), 'c'
  end

  def test_character_outside_range
    assert_equal 'g'.clamp('a', 'e'), 'e'
  end

  def test_error_when_min_above_max
    assert_raise(ArgumentError, 'min must be less than max') do
      assert 5.clamp(4, 3)
    end
  end

  def test_error_when_min_equal_to_max
    assert_raise(ArgumentError, 'min must be less than max') do
      assert 5.clamp(4, 4)
    end
  end

  def test_error_on_bad_comparison
    assert_raise(ArgumentError, /comparison of .* with .* failed/) do
      assert_equal 5.clamp('l', {}), 5
    end
  end
end
