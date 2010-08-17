require 'spec_helper'

describe Arel::Nodes::SelectStatement do
  describe "clone" do
    it "clones cores" do
      statement = Arel::Nodes::SelectStatement.new %w[a b c]

      statement.cores.each_with_index do |o, j|
        o.should_receive(:clone).and_return("#{o}#{j}")
      end

      dolly = statement.clone
      dolly.cores.should == %w[a0 b1 c2]
    end
  end
end
