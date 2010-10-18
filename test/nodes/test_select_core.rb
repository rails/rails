require 'helper'

describe Arel::Nodes::SelectCore do
  describe "#clone" do
    it "clones froms, projections and wheres" do
      core = Arel::Nodes::SelectCore.new
      core.froms       = %w[a b c]
      core.projections = %w[d e f]
      core.wheres      = %w[g h i]

      dolly = core.clone

      dolly.froms.must_equal core.froms
      dolly.projections.must_equal core.projections
      dolly.wheres.must_equal core.wheres

      dolly.froms.wont_be_same_as core.froms
      dolly.projections.wont_be_same_as core.projections
      dolly.wheres.wont_be_same_as core.wheres
    end
  end
end
