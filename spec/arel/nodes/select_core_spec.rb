require 'spec_helper'

describe Arel::Nodes::SelectCore do
  describe "#clone" do
    it "clones froms, projections and wheres" do
      core = Arel::Nodes::SelectCore.new
      core.instance_variable_set "@froms", %w[a b c]
      core.instance_variable_set "@projections", %w[d e f]
      core.instance_variable_set "@wheres", %w[g h i]

      [:froms, :projections, :wheres].each do |array_attr|
        core.send(array_attr).should_receive(:clone).and_return([array_attr])
      end

      dolly = core.clone
      check dolly.froms.should == [:froms]
      check dolly.projections.should == [:projections]
      check dolly.wheres.should == [:wheres]
    end
  end
end
