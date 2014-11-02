require 'abstract_unit'
require 'active_support/core_ext/hash/coalesce'

class CoalesceTest < ActiveSupport::TestCase
  test "coalesce returns a new hash with other hashes merged" do
    h1 = { a: 'a', b: 'b' }
    h2 = { c: 'c' }
    h3 = { b: 'bb' }

    coalesced = h1.coalesce(h2, h3)

    assert_equal({ a: 'a', b: 'bb', c: 'c' }, coalesced)
  end

  test "coalesce! modifies the original" do
    h1 = { a: 'a', b: 'b' }
    h2 = { c: 'c' }
    h3 = { b: 'bb' }

    coalesced = h1.coalesce!(h2, h3)

    assert_equal({ a: 'a', b: 'bb', c: 'c' }, coalesced)
    assert_same h1, coalesced
  end

  test "coalesce takes a block to compute the new value" do
    h1 = { a: 100, b: 200 }
    h2 = { c: 300 }
    h3 = { b: 150 }

    coalesced = h1.coalesce(h2, h3) { |key, this_val, other_val| this_val + other_val }

    assert_equal({ a: 100, b: 350, c: 300 }, coalesced)
  end

  test "coalesce! takes a block to compute the new value and returns the original" do
    h1 = { a: 100, b: 200 }
    h2 = { c: 300 }
    h3 = { b: 150 }

    coalesced = h1.coalesce!(h2, h3) { |key, this_val, other_val| this_val + other_val }

    assert_equal({ a: 100, b: 350, c: 300 }, coalesced)
    assert_same h1, coalesced
  end
end
