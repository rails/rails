require 'spec_helper'

describe Arel::Nodes::DeleteStatement do
  describe "#clone" do
    it "clones wheres" do
      statement = Arel::Nodes::DeleteStatement.new
      statement.wheres = %w[a b c]

      statement.wheres.should_receive(:clone).and_return([:wheres])

      dolly = statement.clone
      dolly.wheres.should == [:wheres]
    end
  end
end
