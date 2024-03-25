# frozen_string_literal: true

require_relative "../helper"

describe Arel::Nodes::UpdateStatement do
  describe "#clone" do
    it "clones wheres, values, and returning" do
      statement = Arel::Nodes::UpdateStatement.new
      statement.wheres    = %w[a b c]
      statement.values    = %w[x y z]
      statement.returning = %w[1 2 3]

      dolly = statement.clone
      _(dolly.wheres).must_equal statement.wheres
      _(dolly.wheres).wont_be_same_as statement.wheres

      _(dolly.values).must_equal statement.values
      _(dolly.values).wont_be_same_as statement.values

      _(dolly.returning).must_equal statement.returning
      _(dolly.returning).wont_be_same_as statement.returning
    end
  end

  describe "equality" do
    it "is equal with equal ivars" do
      statement1 = Arel::Nodes::UpdateStatement.new
      statement1.relation  = "zomg"
      statement1.wheres    = 2
      statement1.values    = false
      statement1.orders    = %w[x y z]
      statement1.limit     = 42
      statement1.key       = "zomg"
      statement1.groups    = ["foo"]
      statement1.havings   = []
      statement1.returning = %w[1 2 3]
      statement2 = Arel::Nodes::UpdateStatement.new
      statement2.relation  = "zomg"
      statement2.wheres    = 2
      statement2.values    = false
      statement2.orders    = %w[x y z]
      statement2.limit     = 42
      statement2.key       = "zomg"
      statement2.groups    = ["foo"]
      statement2.havings   = []
      statement2.returning = %w[1 2 3]

      array = [statement1, statement2]
      assert_equal 1, array.uniq.size
    end

    it "is not equal with different ivars" do
      statement1 = Arel::Nodes::UpdateStatement.new
      statement1.relation  = "zomg"
      statement1.wheres    = 2
      statement1.values    = false
      statement1.orders    = %w[x y z]
      statement1.limit     = 42
      statement1.key       = "zomg"
      statement1.returning = %w[1 2 3]
      statement2 = Arel::Nodes::UpdateStatement.new
      statement2.relation  = "zomg"
      statement2.wheres    = 2
      statement2.values    = false
      statement2.orders    = %w[x y z]
      statement2.limit     = 42
      statement2.key       = "wth"
      statement2.returning = %w[1 2 3]
      array = [statement1, statement2]
      assert_equal 2, array.uniq.size
    end
  end
end
