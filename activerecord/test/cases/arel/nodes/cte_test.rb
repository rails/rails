# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class CteTest < Arel::Spec
      describe "equality" do
        it "is equal with equal ivars" do
          array = [
            Cte.new("foo", "bar", materialized: true),
            Cte.new("foo", "bar", materialized: true)
          ]

          assert_equal 1, array.uniq.size
        end

        it "is not equal with unequal ivars" do
          array = [
            Cte.new("foo", "bar", materialized: true),
            Cte.new("foo", "bar")
          ]

          assert_equal 2, array.uniq.size
        end
      end

      describe "#to_cte" do
        it "returns self" do
          cte = Cte.new("foo", "bar")

          assert_equal cte.to_cte, cte
        end
      end

      describe "#to_table" do
        it "returns an Arel::Table using the Cte's name" do
          table = Cte.new("foo", "bar").to_table

          assert_kind_of Arel::Table, table
          assert_equal "foo", table.name
        end
      end
    end
  end
end
