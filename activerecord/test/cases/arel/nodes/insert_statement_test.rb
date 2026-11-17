# frozen_string_literal: true

require_relative "../helper"

class Arel::Nodes::InsertStatementTest < Arel::Test
  test "#clone clones columns and values" do
    statement = Arel::Nodes::InsertStatement.new
    statement.columns    = %w[a b c]
    statement.values     = %w[x y z]
    statement.returning  = %w[1 2 3]

    dolly = statement.clone
    assert_equal statement.columns, dolly.columns
    assert_equal statement.values, dolly.values
    assert_equal statement.returning, dolly.returning

    assert_not_same statement.columns, dolly.columns
    assert_not_same statement.values, dolly.values
    assert_not_same statement.returning, dolly.returning
  end

  test "equality is equal with equal ivars" do
    statement1 = Arel::Nodes::InsertStatement.new
    statement1.columns    = %w[a b c]
    statement1.values     = %w[x y z]
    statement1.returning  = %w[1 2 3]
    statement2 = Arel::Nodes::InsertStatement.new
    statement2.columns    = %w[a b c]
    statement2.values     = %w[x y z]
    statement2.returning  = %w[1 2 3]
    array = [statement1, statement2]
    assert_equal 1, array.uniq.size
  end

  test "equality is not equal with different ivars" do
    statement1 = Arel::Nodes::InsertStatement.new
    statement1.columns    = %w[a b c]
    statement1.values     = %w[x y z]
    statement1.returning  = %w[1 2 3]
    statement2 = Arel::Nodes::InsertStatement.new
    statement2.columns    = %w[a b c]
    statement2.values     = %w[1 2 3]
    statement2.returning  = %w[1 2 3]
    array = [statement1, statement2]
    assert_equal 2, array.uniq.size
  end
end
