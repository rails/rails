require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Relations::Order do
  before do
    @relation1 = ActiveRelation::Relations::Table.new(:foo)
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
    @attribute1 = @relation1[:id]
    @attribute2 = @relation2[:id]
  end

  describe '#qualify' do
    it "distributes over the relation and attributes" do
      ActiveRelation::Relations::Order.new(@relation1, @attribute1).qualify. \
        should == ActiveRelation::Relations::Order.new(@relation1.qualify, @attribute1.qualify)
    end
  end
  
  describe '#to_sql' do
    it "manufactures sql with an order clause" do
      ActiveRelation::Relations::Order.new(@relation1, @attribute1).to_sql.should be_like("""
        SELECT `foo`.`name`, `foo`.`id`
        FROM `foo`
        ORDER BY `foo`.`id`
      """)
    end
  end
  
end