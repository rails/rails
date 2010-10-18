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
end
