require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe OrderRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute1 = @relation1[:id]
    @attribute2 = @relation2[:id]
  end
  
  describe '==' do
    it "obtains if the relation and attributes are identical" do
      OrderRelation.new(@relation1, @attribute1, @attribute2).should == OrderRelation.new(@relation1, @attribute1, @attribute2)
      OrderRelation.new(@relation1, @attribute1).should_not == OrderRelation.new(@relation2, @attribute1)
      OrderRelation.new(@relation1, @attribute1, @attribute2).should_not == OrderRelation.new(@relation1, @attribute2, @attribute1)
    end
  end
  
  describe '#qualify' do
    it "manufactures an order relation with qualified attributes and qualified relation" do
      OrderRelation.new(@relation1, @attribute1).qualify. \
        should == OrderRelation.new(@relation1.qualify, @attribute1.qualify)
    end
  end
  
  describe '#to_sql' do
    it "manufactures sql with an order clause" do
      OrderRelation.new(@relation1, @attribute1).to_sql.to_s.should == SelectBuilder.new do
        select do
          column :foo, :name
          column :foo, :id
        end
        from :foo
        order_by do
          column :foo, :id
        end
      end.to_s
    end
  end
  
end