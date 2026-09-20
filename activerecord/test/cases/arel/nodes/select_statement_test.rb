# frozen_string_literal: true

require_relative "../helper"

class Arel::Nodes::SelectStatementTest < Arel::Test
  test "#clone clones cores" do
    statement = Arel::Nodes::SelectStatement.new %w[a b c]

    dolly = statement.clone
    assert_equal statement.cores, dolly.cores
    assert_not_same statement.cores, dolly.cores
  end

  test "equality is equal with equal ivars" do
    statement1 = Arel::Nodes::SelectStatement.new %w[a b c]
    statement1.offset = 1
    statement1.limit  = 2
    statement1.lock   = false
    statement1.orders = %w[x y z]
    statement1.with   = "zomg"
    statement2 = Arel::Nodes::SelectStatement.new %w[a b c]
    statement2.offset = 1
    statement2.limit  = 2
    statement2.lock   = false
    statement2.orders = %w[x y z]
    statement2.with   = "zomg"
    array = [statement1, statement2]
    assert_equal 1, array.uniq.size
  end

  test "equality is not equal with different ivars" do
    statement1 = Arel::Nodes::SelectStatement.new %w[a b c]
    statement1.offset = 1
    statement1.limit  = 2
    statement1.lock   = false
    statement1.orders = %w[x y z]
    statement1.with   = "zomg"
    statement2 = Arel::Nodes::SelectStatement.new %w[a b c]
    statement2.offset = 1
    statement2.limit  = 2
    statement2.lock   = false
    statement2.orders = %w[x y z]
    statement2.with   = "wth"
    array = [statement1, statement2]
    assert_equal 2, array.uniq.size
  end
end
