# frozen_string_literal: true

require_relative "../helper"

describe Arel::Nodes::InsertStatement do
  describe "#clone" do
    it "clones columns and values" do
      statement = Arel::Nodes::InsertStatement.new
      statement.columns    = %w[a b c]
      statement.values     = %w[x y z]
      statement.returning  = %w[1 2 3]

      dolly = statement.clone
      _(dolly.columns).must_equal statement.columns
      _(dolly.values).must_equal statement.values
      _(dolly.returning).must_equal statement.returning

      _(dolly.columns).wont_be_same_as statement.columns
      _(dolly.values).wont_be_same_as statement.values
      _(dolly.returning).wont_be_same_as statement.returning
    end
  end

  describe "equality" do
    it "is equal with equal ivars" do
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

    it "is not equal with different ivars" do
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
end
