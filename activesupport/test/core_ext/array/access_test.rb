# frozen_string_literal: true

require_relative '../../abstract_unit'
require 'active_support/core_ext/array'

class AccessTest < ActiveSupport::TestCase
  def test_from
    assert_equal %w( a b c d ), %w( a b c d ).from(0)
    assert_equal %w( c d ), %w( a b c d ).from(2)
    assert_equal %w(), %w( a b c d ).from(10)
    assert_equal %w( d e ), %w( a b c d e ).from(-2)
    assert_equal %w(), %w( a b c d e ).from(-10)
  end

  def test_to
    assert_equal %w( a ), %w( a b c d ).to(0)
    assert_equal %w( a b c ), %w( a b c d ).to(2)
    assert_equal %w( a b c d ), %w( a b c d ).to(10)
    assert_equal %w( a b c ), %w( a b c d ).to(-2)
    assert_equal %w(), %w( a b c ).to(-10)
  end

  def test_specific_accessor
    array = (1..42).to_a

    assert_equal array[1], array.second
    assert_equal array[2], array.third
    assert_equal array[3], array.fourth
    assert_equal array[4], array.fifth
    assert_equal array[41], array.forty_two
    assert_equal array[-3], array.third_to_last
    assert_equal array[-2], array.second_to_last
  end

  def test_including
    assert_equal [1, 2, 3, 4, 5], [1, 2, 4].including(3, 5).sort
    assert_equal [1, 2, 3, 4, 5], [1, 2, 4].including([3, 5]).sort
    assert_equal [[0, 1], [1, 0]], [[0, 1]].including([[1, 0]])
  end

  def test_excluding
    assert_equal [1, 2, 4], [1, 2, 3, 4, 5].excluding(3, 5)
    assert_equal [1, 2, 4], [1, 2, 3, 4, 5].excluding([3, 5])
    assert_equal [[0, 1]], [[0, 1], [1, 0]].excluding([[1, 0]])
  end

  def test_without
    assert_equal [1, 2, 4], [1, 2, 3, 4, 5].without(3, 5)
  end
end
