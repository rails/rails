# frozen_string_literal: true

require_relative "../helper"

class Arel::Nodes::SumTest < Arel::Test
  test "as should alias the sum" do
    table = Arel::Table.new :users
    assert_like %{
      SUM("users"."id") AS foo
    }, table[:id].sum.as("foo").to_sql
  end

  test "equality is equal with equal ivars" do
    array = [Arel::Nodes::Sum.new("foo"), Arel::Nodes::Sum.new("foo")]
    assert_equal 1, array.uniq.size
  end

  test "equality is not equal with different ivars" do
    array = [Arel::Nodes::Sum.new("foo"), Arel::Nodes::Sum.new("foo!")]
    assert_equal 2, array.uniq.size
  end

  test "order should order the sum" do
    table = Arel::Table.new :users
    assert_like %{
      SUM("users"."id") DESC
    }, table[:id].sum.desc.to_sql
  end
end
