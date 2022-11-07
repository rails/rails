# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/array"

class FlipArrayTest < ActiveSupport::TestCase
  def test_returns_new_array_with_flip
    ary = %w( a b c d )

    assert_equal %w( d b c a ), ary.flip(0, 3)
    assert_equal %w( a b c d ), ary
  end

  def test_returns_modified_array_with_flip!
    ary = %w( a b c d )

    assert_equal %w( d b c a ), ary.flip!(0, 3)
    assert_equal %w( d b c a ), ary
  end

  def test_returns_nil_if_from_and_to_the_same_with_flip!
    ary = %w( a b c d )

    assert_nil ary.flip!(0, 0)
    assert_nil ary.flip!(0, -4)
    assert_nil ary.flip!(-1, 3)
  end

  def test_invalid_arguments
    assert_raises(TypeError) { [1, 2].flip(0, "1") }
    assert_raises(TypeError) { [1, 2].flip("0", 1) }

    assert_raises(IndexError) { [1, 2].flip(0, 2) }
    assert_raises(IndexError) { [1, 2].flip(2, 0) }

    assert_raises(TypeError) { [1, 2].flip!(0, "1") }
    assert_raises(TypeError) { [1, 2].flip!("0", 1) }

    assert_raises(IndexError) { [1, 2].flip!(0, 2) }
    assert_raises(IndexError) { [1, 2].flip!(2, 0) }
  end
end
