# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/hash/leaf_values"

class LeafValuesTest < ActiveSupport::TestCase
  test "an empty is returned for an empty hash" do
    subject = {}.leaf_values

    assert_equal subject, []
  end

  test "leaf values are returned for one dimential hashes" do
    subject = { a: "a", b: "b" }.leaf_values

    assert_equal "a", subject.first
    assert_equal "b", subject.last
    assert_equal subject.size, 2
  end

  test "leaf values are returned for multi-dimential hashes" do
    subject = {
      a: {
        b: 2,
        c: {
          d: 4
        }
      },
      e: {
        f: 6,
        g: {
           h: {
             i: 8,
             j: {
               k: 10
             }
           }
        }
      }
    }.leaf_values

    assert_equal subject, [2, 4, 6, 8, 10]
  end
end
