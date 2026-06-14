# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class ::FilterTest < Arel::Test
      test "Filter should add filter to expression" do
        table = Arel::Table.new :users

        assert_like %{
          COUNT("users"."id") FILTER (WHERE "users"."income" >= 40000)
        }, table[:id].count.filter(table[:income].gteq(40_000)).to_sql
      end

      test "Filter as should alias the expression" do
        table = Arel::Table.new :users

        assert_like %{
          COUNT("users"."id") FILTER (WHERE "users"."income" >= 40000) AS rich_users_count
        }, table[:id].count.filter(table[:income].gteq(40_000)).as("rich_users_count").to_sql
      end

      test "Filter over should reference the window definition by name" do
        table = Arel::Table.new :users
        window = Arel::Nodes::Window.new.partition(table[:year])

        assert_like %{
          COUNT("users"."id") FILTER (WHERE "users"."income" >= 40000) OVER (PARTITION BY "users"."year")
        }, table[:id].count.filter(table[:income].gteq(40_000)).over(window).to_sql
      end
    end
  end
end
