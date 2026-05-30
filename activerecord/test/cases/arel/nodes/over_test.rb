# frozen_string_literal: true

require_relative "../helper"

class Arel::Nodes::OverTest < Arel::Test
  test "as should alias the expression" do
    table = Arel::Table.new :users
    assert_like %{
      COUNT("users"."id") OVER () AS foo
    }, table[:id].count.over.as("foo").to_sql
  end

  test "with literal should reference the window definition by name" do
    table = Arel::Table.new :users
    assert_like %{
      COUNT("users"."id") OVER "foo"
    }, table[:id].count.over("foo").to_sql
  end

  test "with SQL literal should reference the window definition by name" do
    table = Arel::Table.new :users
    assert_like %{
      COUNT("users"."id") OVER foo
    }, table[:id].count.over(Arel.sql("foo")).to_sql
  end

  test "with no expression should use empty definition" do
    table = Arel::Table.new :users
    assert_like %{
      COUNT("users"."id") OVER ()
    }, table[:id].count.over.to_sql
  end

  test "with expression should use definition in sub-expression" do
    table = Arel::Table.new :users
    window = Arel::Nodes::Window.new.order(table["foo"])
    assert_like %{
      COUNT("users"."id") OVER (ORDER BY \"users\".\"foo\")
    }, table[:id].count.over(window).to_sql
  end

  test "equality is equal with equal ivars" do
    array = [
      Arel::Nodes::Over.new("foo", "bar"),
      Arel::Nodes::Over.new("foo", "bar")
    ]
    assert_equal 1, array.uniq.size
  end

  test "equality is not equal with different ivars" do
    array = [
      Arel::Nodes::Over.new("foo", "bar"),
      Arel::Nodes::Over.new("foo", "baz")
    ]
    assert_equal 2, array.uniq.size
  end
end
