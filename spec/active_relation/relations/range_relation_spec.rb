require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Relations::Range do
  before do
    @relation1 = ActiveRelation::Relations::Table.new(:foo)
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
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
      ActiveRelation::Relations::Range.new(@relation1, @range2).to_s.should be_like("""
        SELECT `foo`.`name`, `foo`.`id`
        FROM `foo`
        LIMIT #{range_size}
        OFFSET #{range_start}
      """)
    end
  end
  
end