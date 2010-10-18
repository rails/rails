require 'helper'

describe Arel::Nodes::SelectStatement do
  describe "#clone" do
    it "clones cores" do
      statement = Arel::Nodes::SelectStatement.new %w[a b c]

      dolly = statement.clone
      dolly.cores.must_equal      statement.cores
      dolly.cores.wont_be_same_as statement.cores
    end
  end
end
