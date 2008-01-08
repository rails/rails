require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe OrderRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute1 = @relation1[:id]
    @attribute2 = @relation2[:id]
  end

  describe '#qualify' do
    it "distributes over the relation and attributes" do
      OrderRelation.new(@relation1, @attribute1).qualify. \
        should == OrderRelation.new(@relation1.qualify, @attribute1.qualify)
    end
  end
  
  describe '#to_sql' do
    it "manufactures sql with an order clause" do
      OrderRelation.new(@relation1, @attribute1).to_sql.should be_like("""
        SELECT `foo`.`name`, `foo`.`id`
        FROM `foo`
        ORDER BY `foo`.`id`
      """)
    end
  end
  
end