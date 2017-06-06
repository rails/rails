require "abstract_unit"
require "active_support/core_ext/hash/deep_fetch"

class DeepFetchTest < ActiveSupport::TestCase
  test "deep_fetch returns a correct value" do
    hash = { a: { b: 1 } }
    assert_equal(1, hash.deep_fetch(:a, :b))
  end

  test "deep_fetch raises a KeyError if value is missing" do
    hash = { a: { b: 1 } }
    assert_raise KeyError do
      hash.deep_fetch(:a, :c)
    end
  end

  test "deep_fetch raises a NoMethodError if previously retrieved value is not a Hash" do
    hash = { a: "not_a_hash" }

    assert_raise NoMethodError do
      hash.deep_fetch(:a, :b)
    end
  end
end
