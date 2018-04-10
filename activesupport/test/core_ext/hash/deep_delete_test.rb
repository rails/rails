# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/hash/deep_delete"

class DeepDeleteTest < ActiveSupport::TestCase
  test "deep_delete/0 raises an error" do
    initial_data = { a: 1, b: 2 }

    assert_raise ArgumentError do
      initial_data.deep_delete
    end
  end

  test "deep_delete called on empty hash and returns it" do
    initial_data = {}
    result_data = initial_data.deep_delete(:a)

    assert_equal(initial_data, result_data)
  end

  test "deep_delete called on 1-lv nested hash and returns modified data" do
    initial_data = { a: 1, b: 2 }
    result_data = initial_data.deep_delete(:a)

    assert_equal({ b: 2 }, result_data)
  end

  test "deep_delete called on 2-lv nested hash and returns modified data" do
    initial_data = { a: 1, b: { c: 3 } }
    result_data = initial_data.deep_delete(:c)

    assert_equal({ a: 1, b: {} }, result_data)
  end

  test "deep_delete called on 3-lv nested hash and returns modified data" do
    initial_data = { a: 1, b: { c: { d: 3 } } }
    result_data = initial_data.deep_delete(:d)

    assert_equal({ a: 1, b: { c: {} } }, result_data)
  end

  test "deep_delete called on hash with keys in different nesting levels and remove it all to highest level" do
    initial_data = { a: 1, b: { c: { b: 3 } } }
    result_data = initial_data.deep_delete(:b)

    assert_equal({ a: 1 }, result_data)
  end

  test "deep_delete called on hash with keys which not included in args" do
    initial_data = { a: 1, b: 2 }
    result_data = result_data.deep_delete(:c)

    assert_equal(initial_data, result_data)
  end

  test "deep delete called with a few keys in args" do
    initial_data = { a: 1, b: { c: 3 }, d: 4 }
    result_data = initial_data.deep_delete(:b, :d)

    assert_equal({ a: 1 }, result_data)
  end
end
