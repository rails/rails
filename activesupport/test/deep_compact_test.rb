# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/hash/deep_compact"

class DeepCompactTest < ActiveSupport::TestCase
  test "removes nils recursively" do
    h = { a: 1, b: nil, c: { d: nil, e: 2 }, f: [1, nil, { g: nil, h: 3 }] }
    expected = { a: 1, c: { e: 2 }, f: [1, { h: 3 }] }
    assert_equal expected, h.deep_compact
    assert h.key?(:b)
  end

  test "bang version mutates" do
    h = { a: nil, b: { c: nil, d: 1 } }
    h.deep_compact!
    assert_equal({ b: { d: 1 } }, h)
  end

  test "blank: true removes blank values" do
    h = { a: "", b: " ", c: [], d: {}, e: 0 }
    assert_equal({ e: 0 }, h.deep_compact(remove_blank: true))
  end

  test "handles nested arrays of arrays" do
    h = { x: [[nil, 1], [nil, [2, nil]]] }
    assert_equal({ x: [[1], [ [2] ]] }, h.deep_compact)
  end

  test "leaves empty collections (decision)" do
    h = { x: { y: nil } }
    assert_equal({ x: {} }, h.deep_compact)
  end
end
