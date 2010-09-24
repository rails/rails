require 'spec_helper'

describe Arel::Nodes::SelectStatement do
  describe "#clone" do
    it "clones cores" do
      statement = Arel::Nodes::SelectStatement.new %w[a b c]

      statement.cores.map { |x| x.should_receive(:clone).and_return(:f) }

      dolly = statement.clone
      dolly.cores.should == [:f, :f, :f]
    end
  end
end
