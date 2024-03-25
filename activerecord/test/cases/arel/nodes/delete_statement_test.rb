# frozen_string_literal: true

require_relative "../helper"

describe Arel::Nodes::DeleteStatement do
  describe "#clone" do
    it "clones wheres and returning" do
      statement = Arel::Nodes::DeleteStatement.new
      statement.wheres    = %w[a b c]
      statement.returning = %w[1 2 3]

      dolly = statement.clone
      _(dolly.wheres).must_equal statement.wheres
      _(dolly.wheres).wont_be_same_as statement.wheres

      _(dolly.returning).must_equal statement.returning
      _(dolly.returning).wont_be_same_as statement.returning
    end
  end

  describe "equality" do
    it "is equal with equal ivars" do
      statement1 = Arel::Nodes::DeleteStatement.new
      statement1.wheres = %w[a b c]
      statement1.returning = %w[1 2 3]
      statement2 = Arel::Nodes::DeleteStatement.new
      statement2.wheres = %w[a b c]
      statement2.returning = %w[1 2 3]
      array = [statement1, statement2]
      assert_equal 1, array.uniq.size
    end

    it "is not equal with different ivars" do
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
end
