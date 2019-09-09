# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/array"

class EvenOddTest < ActiveSupport::TestCase
  def test_even
    assert_equal true, %w( a b c d ).even?
    assert_equal false, %w( a b c ).even?
  end

  def test_odd
    assert_equal true, %w( a b c ).odd?
    assert_equal false, %w( a b c d ).odd?
  end
end
