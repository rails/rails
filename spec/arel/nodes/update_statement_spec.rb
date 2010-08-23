require 'spec_helper'

describe Arel::Nodes::UpdateStatement do
  describe "#clone" do
    it "clones wheres and values" do
      statement = Arel::Nodes::UpdateStatement.new
      statement.wheres = %w[a b c]
      statement.values = %w[x y z]

      statement.wheres.each_with_index do |o, j|
        o.should_receive(:clone).and_return("#{o}#{j}")
      end
      statement.values.each_with_index do |o, j|
        o.should_receive(:clone).and_return("#{o}#{j}")
      end

      dolly = statement.clone
      check dolly.wheres.should == %w[a0 b1 c2]
      check dolly.values.should == %w[x0 y1 z2]
    end
  end
end
