require 'spec_helper'

describe Arel::Nodes::SelectCore do
  describe "#clone" do
    it "clones froms, projections and wheres" do
      core = Arel::Nodes::SelectCore.new
      core.instance_variable_set "@froms", %w[a b c]
      core.instance_variable_set "@projections", %w[d e f]
      core.instance_variable_set "@wheres", %w[g h i]

      [:froms, :projections, :wheres].each do |array_attr|
        core.send(array_attr).each_with_index do |o, j|
          o.should_receive(:clone).and_return("#{o}#{j}")
        end
      end

      dolly = core.clone
      check dolly.froms.should == %w[a0 b1 c2]
      check dolly.projections.should == %w[d0 e1 f2]
      check dolly.wheres.should == %w[g0 h1 i2]
    end
  end
end
