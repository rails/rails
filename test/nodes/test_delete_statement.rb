require 'helper'

describe Arel::Nodes::DeleteStatement do
  describe "#clone" do
    it "clones wheres" do
      statement = Arel::Nodes::DeleteStatement.new
      statement.wheres = %w[a b c]

      dolly = statement.clone
      dolly.wheres.must_equal statement.wheres
      dolly.wheres.wont_be_same_as statement.wheres
    end
  end
end
