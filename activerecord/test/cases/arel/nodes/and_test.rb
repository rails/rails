# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class AndTest < Arel::Test
      test "equality is equal with equal ivars" do
        array = [And.new(["foo", "bar"]), And.new(["foo", "bar"])]
        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with different ivars" do
        array = [And.new(["foo", "bar"]), And.new(["foo", "baz"])]
        assert_equal 2, array.uniq.size
      end

      test "functions as node expression allows aliasing" do
        aliased = And.new(["foo", "bar"]).as("baz")

        assert_kind_of As, aliased
        assert_kind_of SqlLiteral, aliased.right
      end
    end
  end
end
