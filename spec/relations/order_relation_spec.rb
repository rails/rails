require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe OrderRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute1 = @relation1[:foo]
    @attribute2 = @relation2[:bar]
  end
  
  describe OrderRelation, '==' do
    it "obtains if the relation and attributes are identical" do
      OrderRelation.new(@relation1, @attribute1, @attribute2).should == OrderRelation.new(@relation1, @attribute1, @attribute2)
      OrderRelation.new(@relation1, @attribute1).should_not == OrderRelation.new(@relation2, @attribute1)
      OrderRelation.new(@relation1, @attribute1, @attribute2).should_not == OrderRelation.new(@relation1, @attribute2, @attribute1)
    end
  end
end