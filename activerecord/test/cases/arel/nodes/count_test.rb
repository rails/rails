# frozen_string_literal: true

require_relative "../helper"

class Arel::Nodes::CountTest < Arel::Test
  test "as should alias the count" do
    table = Arel::Table.new :users
    assert_like %{
      COUNT("users"."id") AS foo
    }, table[:id].count.as("foo").to_sql
  end

  test "eq should compare the count" do
    table = Arel::Table.new :users
    assert_like %{
      COUNT("users"."id") = 2
    }, table[:id].count.eq(2).to_sql
  end

  test "equality is equal with equal ivars" do
    array = [Arel::Nodes::Count.new("foo"), Arel::Nodes::Count.new("foo")]
    assert_equal 1, array.uniq.size
  end

  test "equality is not equal with different ivars" do
    array = [Arel::Nodes::Count.new("foo"), Arel::Nodes::Count.new("foo!")]
    assert_equal 2, array.uniq.size
  end
end
