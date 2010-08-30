require 'spec_helper'

describe Arel::Nodes::InsertStatement do
  describe "#clone" do
    it "clones columns and values" do
      statement = Arel::Nodes::InsertStatement.new
      statement.columns = %w[a b c]
      statement.values  = %w[x y z]

      statement.columns.should_receive(:clone).and_return([:columns])
      statement.values.should_receive(:clone).and_return([:values])

      dolly = statement.clone
      check dolly.columns.should == [:columns]
      check dolly.values.should  == [:values]
    end
  end
end
