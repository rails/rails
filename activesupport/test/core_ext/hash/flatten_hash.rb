# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/hash/flatten_hash"

class FlattenHashTest < ActiveSupport::TestCase
  test "flatten hash" do
    hash1 = { a: true, b: { c: { d: 1 } } }
    result1 = { a: true, d: 1 }
    assert_equal result1, hash1.flatten_hash

    hash2 = { a: true, b: { c: 1, d: { e: "saleh" } } }
    result2 = { a: true, c: 1, e: "saleh" }
    assert_equal result2, hash2.flatten_hash

    hash3 = { a: true, b: { c: 1, d: { e: { f: "salem" } } } }
    result3 = { a: true, c: 1, f: "salem" }
    assert_equal result3, hash3.flatten_hash
  end
end
