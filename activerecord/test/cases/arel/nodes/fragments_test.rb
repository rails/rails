# frozen_string_literal: true

require_relative "../helper"
require "yaml"

module Arel
  module Nodes
    class FragmentsTest < Arel::Test
      test "equality is equal with equal values" do
        array = [Fragments.new(["foo", "bar"]), Fragments.new(["foo", "bar"])]
        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with different values" do
        array = [Fragments.new(["foo"]), Fragments.new(["bar"])]
        assert_equal 2, array.uniq.size
      end

      test "equality can be joined with other nodes" do
        fragments = Fragments.new(["foo", "bar"])
        sql = Arel.sql("SELECT")
        joined_fragments = fragments + sql

        assert_equal ["foo", "bar"], fragments.values
        assert_equal ["foo", "bar", sql], joined_fragments.values
      end

      test "equality fails if joined with something that is not an Arel node" do
        fragments = Fragments.new
        assert_raises ArgumentError do
          fragments + "Not a node"
        end
      end
    end
  end
end
