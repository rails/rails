require "abstract_unit"
require "active_support/core_ext/hash/deep_compact"

class DeepCompactTest < ActiveSupport::TestCase
  test "Remove all nil values" do
    original = { a: "a", b: "b", c: nil, d: {e: nil, f: 1} }
    original.deep_compact!

    assert_equal({ a: "a", b: "b", d: {f: 1} }, original)
  end

  test "Remove all nil values without side effect other" do
    original = { a: "a", b: "b", c: nil, d: {e: nil, f: 1} }
    mapped = original.deep_compact

    assert_equal({ a: "a", b: "b", c: nil, d: {e: nil, f: 1} }, original)
    assert_equal({ a: "a", b: "b", d: {f: 1} }, mapped)
  end
end
