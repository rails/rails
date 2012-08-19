require 'helper'

describe Arel::Nodes::UpdateStatement do
  describe "#clone" do
    it "clones wheres and values" do
      statement = Arel::Nodes::UpdateStatement.new
      statement.wheres = %w[a b c]
      statement.values = %w[x y z]

      dolly = statement.clone
      dolly.wheres.must_equal statement.wheres
      dolly.wheres.wont_be_same_as statement.wheres

      dolly.values.must_equal statement.values
      dolly.values.wont_be_same_as statement.values
    end
  end

  describe 'equality' do
    it 'is equal with equal ivars' do
      statement1 = Arel::Nodes::UpdateStatement.new
      statement1.relation = 'zomg'
      statement1.wheres   = 2
      statement1.values   = false
      statement1.orders   = %w[x y z]
      statement1.limit    = 42
      statement1.key      = 'zomg'
      statement2 = Arel::Nodes::UpdateStatement.new
      statement2.relation = 'zomg'
      statement2.wheres   = 2
      statement2.values   = false
      statement2.orders   = %w[x y z]
      statement2.limit    = 42
      statement2.key      = 'zomg'
      array = [statement1, statement2]
      assert_equal 1, array.uniq.size
    end

    it 'is not equal with different ivars' do
      statement1 = Arel::Nodes::UpdateStatement.new
      statement1.relation = 'zomg'
      statement1.wheres   = 2
      statement1.values   = false
      statement1.orders   = %w[x y z]
      statement1.limit    = 42
      statement1.key      = 'zomg'
      statement2 = Arel::Nodes::UpdateStatement.new
      statement2.relation = 'zomg'
      statement2.wheres   = 2
      statement2.values   = false
      statement2.orders   = %w[x y z]
      statement2.limit    = 42
      statement2.key      = 'wth'
      array = [statement1, statement2]
      assert_equal 2, array.uniq.size
    end
  end
end
