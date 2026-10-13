# frozen_string_literal: true

require_relative "../helper"

class Arel::Nodes::DeleteStatementTest < Arel::Test
  test "#clone clones wheres and returning" do
    statement = Arel::Nodes::DeleteStatement.new
    statement.wheres    = %w[a b c]
    statement.returning = %w[1 2 3]

    dolly = statement.clone
    assert_equal statement.wheres, dolly.wheres
    assert_not_same statement.wheres, dolly.wheres
    assert_equal statement.returning, dolly.returning
    assert_not_same statement.returning, dolly.returning
  end

  test "equality is equal with equal ivars" do
    statement1 = Arel::Nodes::DeleteStatement.new
    statement1.wheres = %w[a b c]
    statement1.returning = %w[1 2 3]
    statement2 = Arel::Nodes::DeleteStatement.new
    statement2.wheres = %w[a b c]
    statement2.returning = %w[1 2 3]
    array = [statement1, statement2]
    assert_equal 1, array.uniq.size
  end

  test "equality is not equal with different ivars" do
    statement1 = Arel::Nodes::DeleteStatement.new
    statement1.wheres = %w[a b c]
    statement1.returning = %w[1 2 3]
    statement2 = Arel::Nodes::DeleteStatement.new
    statement2.wheres = %w[1 2 3]
    statement2.returning = %w[a b c]
    array = [statement1, statement2]
    assert_equal 2, array.uniq.size
  end
end
