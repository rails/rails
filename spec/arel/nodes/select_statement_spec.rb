require 'spec_helper'

describe Arel::Nodes::SelectStatement do
  describe "#clone" do
    it "clones cores" do
      statement = Arel::Nodes::SelectStatement.new %w[a b c]

      statement.cores.should_receive(:clone).and_return([:cores])

      dolly = statement.clone
      dolly.cores.should == [:cores]
    end
  end
end
