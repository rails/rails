require 'spec_helper'

describe Arel::Nodes::InsertStatement do
  describe "#clone" do
    it "clones columns and values" do
      statement = Arel::Nodes::InsertStatement.new
      statement.columns = %w[a b c]
      statement.values  = %w[x y z]

      statement.columns.each_with_index do |o, j|
        o.should_receive(:clone).and_return("#{o}#{j}")
      end
      statement.values.each_with_index do |o, j|
        o.should_receive(:clone).and_return("#{o}#{j}")
      end

      dolly = statement.clone
      dolly.columns.should == %w[a0 b1 c2]
      dolly.values.should  == %w[x0 y1 z2]
    end
  end
end
