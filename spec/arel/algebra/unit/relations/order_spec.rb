require 'spec_helper'

module Arel
  describe Order do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe "#==" do
      it "returns true when the Orders are for the same attribute and direction" do
        Ascending.new(@attribute).should == Ascending.new(@attribute)
      end

      it "returns false when the Orders are for a diferent direction" do
        Ascending.new(@attribute).should_not == Descending.new(@attribute)
      end
    end
  end
end

