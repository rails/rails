require 'helper'

describe Arel::Nodes::InsertStatement do
  describe "#clone" do
    it "clones columns and values" do
      statement = Arel::Nodes::InsertStatement.new
      statement.columns = %w[a b c]
      statement.values  = %w[x y z]

      dolly = statement.clone
      dolly.columns.must_equal statement.columns
      dolly.values.must_equal statement.values

      dolly.columns.wont_be_same_as statement.columns
      dolly.values.wont_be_same_as statement.values
    end
  end
end
