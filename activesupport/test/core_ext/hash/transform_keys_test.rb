require 'abstract_unit'
require 'active_support/core_ext/hash/keys'

class TransformKeysTest < ActiveSupport::TestCase
  test "transform_keys returns a new hash with the keys computed from the block" do
    original = { a: 'a', b: 'b' }
    mapped = original.transform_keys { |k| "#{k}!".to_sym }

    assert_equal({ a: 'a', b: 'b' }, original)
    assert_equal({ a!: 'a', b!: 'b' }, mapped)
  end

  test "transform_keys! modifies the keys of the original" do
    original = { a: 'a', b: 'b' }
    mapped = original.transform_keys! { |k| "#{k}!".to_sym }

    assert_equal({ a!: 'a', b!: 'b' }, original)
    assert_same original, mapped
  end

  test "transform_keys returns an Enumerator if no block is given" do
    original = { a: 'a', b: 'b' }
    enumerator = original.transform_keys
    assert_equal Enumerator, enumerator.class
  end

  test "transform_keys is chainable with Enumerable methods" do
    original = { a: 'a', b: 'b' }
    mapped = original.transform_keys.with_index { |k, i| [k, i].join.to_sym }
    assert_equal({ a0: 'a', b1: 'b' }, mapped)
  end
end
