# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class CteTest < Arel::Test
      test "equality is equal with equal ivars" do
        array = [
          Cte.new("foo", "bar", materialized: true),
          Cte.new("foo", "bar", materialized: true)
        ]

        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with unequal ivars" do
        array = [
          Cte.new("foo", "bar", materialized: true),
          Cte.new("foo", "bar")
        ]

        assert_equal 2, array.uniq.size
      end

      test "#to_cte returns self" do
        cte = Cte.new("foo", "bar")

        assert_equal cte.to_cte, cte
      end

      test "#to_table returns an Arel::Table using the Cte's name" do
        table = Cte.new("foo", "bar").to_table

        assert_kind_of Arel::Table, table
        assert_equal "foo", table.name
      end
    end
  end
end
