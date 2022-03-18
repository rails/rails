# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class ::FilterTest < Arel::Spec
      describe "Filter" do
        it "should add filter to expression" do
          table = Arel::Table.new :users
          _(table[:id].count.filter(table[:income].gteq(40_000)).to_sql).must_be_like %{
              COUNT("users"."id") FILTER (WHERE "users"."income" >= 40000)
            }
        end

        describe "as" do
          it "should alias the expression" do
            table = Arel::Table.new :users
            _(table[:id].count.filter(table[:income].gteq(40_000)).as("rich_users_count").to_sql).must_be_like %{
              COUNT("users"."id") FILTER (WHERE "users"."income" >= 40000) AS rich_users_count
            }
          end
        end

        describe "over" do
          it "should reference the window definition by name" do
            table = Arel::Table.new :users
            window = Arel::Nodes::Window.new.partition(table[:year])
            _(table[:id].count.filter(table[:income].gteq(40_000)).over(window).to_sql).must_be_like %{
              COUNT("users"."id") FILTER (WHERE "users"."income" >= 40000) OVER (PARTITION BY "users"."year")
            }
          end
        end
      end
    end
  end
end
