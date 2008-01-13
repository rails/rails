require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Primitives::Attribute do
  before do
    @relation1 = ActiveRelation::Relations::Table.new(:foo)
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
  end
  
  describe '#alias' do
    it "manufactures an aliased attributed" do
      @relation1[:id].alias(:alias).should == ActiveRelation::Primitives::Attribute.new(@relation1, :id, :alias)
    end
  end
  
  describe '#qualified_name' do
    it "manufactures an attribute name prefixed with the relation's name" do
      @relation1[:id].qualified_name.should == 'foo.id'
    end
  end
  
  describe '#qualify' do
    it "manufactures an attribute aliased with that attributes qualified name" do
      @relation1[:id].qualify.should == @relation1[:id].qualify
    end
  end
  
  describe '==' do
    it "obtains if the relation and attribute name are identical" do
      ActiveRelation::Primitives::Attribute.new(@relation1, :name).should == ActiveRelation::Primitives::Attribute.new(@relation1, :name)
      ActiveRelation::Primitives::Attribute.new(@relation1, :name).should_not == ActiveRelation::Primitives::Attribute.new(@relation1, :another_name)
      ActiveRelation::Primitives::Attribute.new(@relation1, :name).should_not == ActiveRelation::Primitives::Attribute.new(@relation2, :name)
    end
  end
  
  describe 'predications' do
    before do
      @attribute1 = ActiveRelation::Primitives::Attribute.new(@relation1, :name)
      @attribute2 = ActiveRelation::Primitives::Attribute.new(@relation2, :name)
    end
    
    describe '#equals' do
      it "manufactures an equality predicate" do
        @attribute1.equals(@attribute2).should == ActiveRelation::Predicates::Equality.new(@attribute1, @attribute2)
      end
    end
    
    describe '#less_than' do
      it "manufactures a less-than predicate" do
        @attribute1.less_than(@attribute2).should == ActiveRelation::Predicates::LessThan.new(@attribute1, @attribute2)
      end
    end
    
    describe '#less_than_or_equal_to' do
      it "manufactures a less-than or equal-to predicate" do
        @attribute1.less_than_or_equal_to(@attribute2).should == ActiveRelation::Predicates::LessThanOrEqualTo.new(@attribute1, @attribute2)
      end
    end
    
    describe '#greater_than' do
      it "manufactures a greater-than predicate" do
        @attribute1.greater_than(@attribute2).should == ActiveRelation::Predicates::GreaterThan.new(@attribute1, @attribute2)
      end
    end
    
    describe '#greater_than_or_equal_to' do
      it "manufactures a greater-than or equal to predicate" do
        @attribute1.greater_than_or_equal_to(@attribute2).should == ActiveRelation::Predicates::GreaterThanOrEqualTo.new(@attribute1, @attribute2)
      end
    end
    
    describe '#matches' do
      it "manufactures a match predicate" do
        @attribute1.matches(/.*/).should == ActiveRelation::Predicates::Match.new(@attribute1, @attribute2)
      end
    end
  end
  
  describe 'aggregations' do
    before do
      @attribute1 = ActiveRelation::Primitives::Attribute.new(@relation1, :name)    
    end
    
    describe '#count' do
      it "manufactures a count aggregation" do
        @attribute1.count.should == ActiveRelation::Primitives::Aggregation.new(@attribute1, "COUNT")
      end
    end
    
    describe '#sum' do
      it "manufactures a sum aggregation" do
        @attribute1.sum.should == ActiveRelation::Primitives::Aggregation.new(@attribute1, "SUM")
      end
    end
    
    describe '#maximum' do
      it "manufactures a maximum aggregation" do
        @attribute1.maximum.should == ActiveRelation::Primitives::Aggregation.new(@attribute1, "MAX")
      end
    end
    
    describe '#minimum' do
      it "manufactures a minimum aggregation" do
        @attribute1.minimum.should == ActiveRelation::Primitives::Aggregation.new(@attribute1, "MIN")
      end
    end
    
    describe '#average' do
      it "manufactures an average aggregation" do
        @attribute1.average.should == ActiveRelation::Primitives::Aggregation.new(@attribute1, "AVG")
      end
    end
    
    
  end
end
