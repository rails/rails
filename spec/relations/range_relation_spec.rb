require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe RangeRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @range1 = 1..2
    @range2 = 4..9
  end
  
  describe '==' do
    it "obtains if the relation and range are identical" do
      RangeRelation.new(@relation1, @range1).should == RangeRelation.new(@relation1, @range1)
      RangeRelation.new(@relation1, @range1).should_not == RangeRelation.new(@relation2, @range1)
      RangeRelation.new(@relation1, @range1).should_not == RangeRelation.new(@relation1, @range2)
    end
  end
  
  describe '#to_sql' do
    it "manufactures sql with limit and offset" do
      range_size = @range2.last - @range2.first + 1
      range_start = @range2.first
      RangeRelation.new(@relation1, @range2).to_sql.to_s.should == SelectBuilder.new do
        select :*
        from :foo
        limit range_size
        offset range_start
      end.to_s
    end
  end
  
end