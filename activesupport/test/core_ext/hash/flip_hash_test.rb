# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/hash"

class FlipHashTest < ActiveSupport::TestCase
  def test_returns_new_hash_with_flip
    hsh = { a: 1, b: 2, c: 3 }

    assert_equal({ a: 2, b: 1, c: 3 }, hsh.flip(:a, :b))
    assert_equal({ a: 1, b: 2, c: 3 }, hsh)
  end

  def test_returns_modified_hash_with_flip!
    hsh = { a: 1, b: 2, c: 3 }

    assert_equal({ a: 2, b: 1, c: 3 }, hsh.flip!(:a, :b))
    assert_equal({ a: 2, b: 1, c: 3 }, hsh)
  end

  def test_returns_nil_if_from_and_to_the_same_with_flip!
    hsh = { a: 1, b: 2, c: 3 }

    assert_nil hsh.flip!(:a, :a)
    assert_nil hsh.with_indifferent_access.flip!("a", :a)
  end

  def test_invalid_arguments
    assert_raises(KeyError) { { a: 1, b: 2, c: 3 }.flip(:a, :d) }
    assert_raises(KeyError) { { a: 1, b: 2, c: 3 }.flip(:d, :a) }
  end
end
