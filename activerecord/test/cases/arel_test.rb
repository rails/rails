# frozen_string_literal: true

require "cases/helper"

class ArelTest < ActiveRecord::TestCase
  test ".sql returns a Arel::Nodes::SqlLiteral node" do
    value = Arel.sql("FUNCTION()")
    assert_kind_of Arel::Nodes::SqlLiteral, value
    assert_equal "FUNCTION()", value
  end

  test ".sql with numeric value returns a Arel::Nodes::SqlLiteral node" do
    value = Arel.sql(12)
    assert_kind_of Arel::Nodes::SqlLiteral, value
    assert_equal "12", value
  end

  test ".sql with bypass_numeric_quoting=true returns a Arel::Nodes::SqlLiteral node" do
    value = Arel.sql(12, bypass_numeric_quoting: true)
    assert_kind_of Arel::Nodes::SqlLiteral, value
    assert_equal "12", value
  end

  test ".star returns a Arel::Nodes::SqlLiteral '*'" do
    value = Arel.star
    assert_kind_of Arel::Nodes::SqlLiteral, value
    assert_equal "*", value
  end

  test ".arel_node? checks if the object is an Arel node" do
    assert Arel.arel_node?(Arel::Nodes::Node.new)
    assert Arel.arel_node?(Arel::Attribute.new)
    assert Arel.arel_node?(Arel::Nodes::SqlLiteral.new(""))
    assert_not Arel.arel_node?(Object.new)
  end

  test ".fetch_attribute delegates to the value" do
    mock = Minitest::Mock.new
    mock.expect(:fetch_attribute, "value")
    assert_equal "value", Arel.fetch_attribute(mock)
  end

  test ".fetch_attribute does not delegate if the value is String" do
    assert_nil Arel.fetch_attribute("str")
  end
end
