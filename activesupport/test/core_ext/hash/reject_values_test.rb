require 'abstract_unit'
require 'active_support/core_ext/hash/reject_values'

class RejectValuesTest < ActiveSupport::TestCase
  test "reject_values returns a new hash with the keys rejected by value from the block" do
    original = { a: 1, b: 2, c: 3 }
    mapped = original.reject_values(&:even?)

    assert_equal({ a: 1, b: 2, c: 3 }, original)
    assert_equal({ a: 1, c: 3 }, mapped)
  end

  test "reject_values! rejects the keys of the original by the value from the block" do
    original = { a: 1, b: 2, c: 3 }
    mapped = original.reject_values!(&:odd?)

    assert_equal({ b: 2 }, original)
    assert_same original, mapped
  end

  test "reject_values returns an Enumerator if no block is given" do
    enumerator = { a: 1, b: 2, c: 3 }.reject_values
    assert_equal Enumerator, enumerator.class
  end

  test "reject_values is chainable with Enumerable methods" do
    original = { a: 1, b: 2, c: 3 }
    mapped = original.reject_values.with_index { |v, i| i.even? }
    assert_equal({ b: 2 }, mapped)
  end
end
