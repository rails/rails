require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe RangeRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @range1 = 1..2
    @range2 = Time.now..2.days.from_now
  end
  
  describe RangeRelation, '==' do
    it "obtains if the relation and range are identical" do
      RangeRelation.new(@relation1, @range1).should == RangeRelation.new(@relation1, @range1)
      RangeRelation.new(@relation1, @range1).should_not == RangeRelation.new(@relation2, @range1)
      RangeRelation.new(@relation1, @range1).should_not == RangeRelation.new(@relation1, @range2)
    end
  end
end