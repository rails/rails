require 'spec_helper'

describe Arel::Nodes::UpdateStatement do
  describe "#clone" do
    it "clones wheres and values" do
      statement = Arel::Nodes::UpdateStatement.new
      statement.wheres = %w[a b c]
      statement.values = %w[x y z]

      statement.wheres.should_receive(:clone).and_return([:wheres])
      statement.values.should_receive(:clone).and_return([:values])

      dolly = statement.clone
      check dolly.wheres.should == [:wheres]
      check dolly.values.should == [:values]
    end
  end
end
