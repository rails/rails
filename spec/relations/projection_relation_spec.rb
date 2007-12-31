require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe ProjectionRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute1 = @relation1[:foo]
    @attribute2 = @relation2[:bar]
  end
  
  describe '==' do
    it "obtains if the relations and attributes are identical" do
      ProjectionRelation.new(@relation1, @attribute1, @attribute2).should == ProjectionRelation.new(@relation1, @attribute1, @attribute2)
      ProjectionRelation.new(@relation1, @attribute1).should_not == ProjectionRelation.new(@relation2, @attribute1)
      ProjectionRelation.new(@relation1, @attribute1).should_not == ProjectionRelation.new(@relation1, @attribute2)
    end
  end
  
  describe '#to_sql' do
    it "manufactures sql with a limited select clause" do
      ProjectionRelation.new(@relation1, @attribute1).to_sql.should == SelectBuilder.new do
        select 'foo.foo'
        from :foo
      end
    end
  end
end