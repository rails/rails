require 'abstract_unit'
require 'active_support/core_ext/hash/deep_compact'

class DeepCompactTest < ActiveSupport::TestCase
  test "deep_compact returns hash without nullable keys" do
    original = { a: true, b: false, c: nil, d: 'd', e: { f: 1, g: nil } }
    compacted = original.deep_compact

    assert_equal({ a: true, b: false, d: 'd', e: { f: 1 } }, compacted)
    assert_not_equal(original, compacted)
  end

  test "deep_compact! modifies original hash to remove nullable keys" do
    original = { a: true, b: false, c: nil, d: 'd', e: { f: 1, g: nil } }
    compacted = original.deep_compact!

    assert_equal({ a: true, b: false, d: 'd', e: { f: 1 } }, compacted)
    assert_equal(original, compacted)
  end
end
