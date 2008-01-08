require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe RangeRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @range1 = 1..2
    @range2 = 4..9
  end

  describe '#qualify' do
    it "distributes over the relation and attributes" do
      pending
    end
  end
  
  describe '#to_sql' do
    it "manufactures sql with limit and offset" do
      range_size = @range2.last - @range2.first + 1
      range_start = @range2.first
      RangeRelation.new(@relation1, @range2).to_s.should be_like("""
        SELECT `foo`.`name`, `foo`.`id`
        FROM `foo`
        LIMIT #{range_size}
        OFFSET #{range_start}
      """)
    end
  end
  
end