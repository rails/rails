require 'spec_helper'

describe Arel::Nodes::SelectStatement do
  describe "#clone" do
    it "clones where" do
      statement = Arel::Nodes::DeleteStatement.new
      statement.wheres = %w[a b c]

      statement.wheres.each_with_index do |o, j|
        o.should_receive(:clone).and_return("#{o}#{j}")
      end

      dolly = statement.clone
      dolly.wheres.should == %w[a0 b1 c2]
    end
  end
end
