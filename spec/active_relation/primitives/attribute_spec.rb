require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Attribute do
    before do
      @relation1 = Table.new(:foo)
      @relation2 = Table.new(:bar)
    end
  
    describe '#as' do
      it "manufactures an aliased attributed when provided a parameter" do
        @relation1[:id].as(:alias).should == Attribute.new(@relation1, :id, :alias)
      end
    end
  
    describe '#qualified_name' do
      it "manufactures an attribute name prefixed with the relation's name" do
        @relation1[:id].qualified_name.should == 'foo.id'
      end
    
      it "manufactures an attribute name prefixed with the relation's aliased name" do
        @relation1.as(:bar)[:id].qualified_name.should == 'bar.id'
      end
    end
  
    describe '#qualify' do
      it "manufactures an attribute aliased with that attributes qualified name" do
        @relation1[:id].qualify.should == @relation1[:id].qualify
      end
    end
  
    describe '==' do
      it "obtains if the relation and attribute name are identical" do
        Attribute.new(@relation1, :name).should == Attribute.new(@relation1, :name)
        Attribute.new(@relation1, :name).should_not == Attribute.new(@relation1, :another_name)
        Attribute.new(@relation1, :name).should_not == Attribute.new(@relation2, :name)
      end
    end
  
    describe 'predications' do
      before do
        @attribute1 = Attribute.new(@relation1, :name)
        @attribute2 = Attribute.new(@relation2, :name)
      end
    
      describe '#equals' do
        it "manufactures an equality predicate" do
          @attribute1.equals(@attribute2).should == Equality.new(@attribute1, @attribute2)
        end
      end
    
      describe '#less_than' do
        it "manufactures a less-than predicate" do
          @attribute1.less_than(@attribute2).should == LessThan.new(@attribute1, @attribute2)
        end
      end
    
      describe '#less_than_or_equal_to' do
        it "manufactures a less-than or equal-to predicate" do
          @attribute1.less_than_or_equal_to(@attribute2).should == LessThanOrEqualTo.new(@attribute1, @attribute2)
        end
      end
    
      describe '#greater_than' do
        it "manufactures a greater-than predicate" do
          @attribute1.greater_than(@attribute2).should == GreaterThan.new(@attribute1, @attribute2)
        end
      end
    
      describe '#greater_than_or_equal_to' do
        it "manufactures a greater-than or equal to predicate" do
          @attribute1.greater_than_or_equal_to(@attribute2).should == GreaterThanOrEqualTo.new(@attribute1, @attribute2)
        end
      end
    
      describe '#matches' do
        it "manufactures a match predicate" do
          @attribute1.matches(/.*/).should == Match.new(@attribute1, @attribute2)
        end
      end
    end
  
    describe 'aggregations' do
      before do
        @attribute1 = Attribute.new(@relation1, :name)    
      end
    
      describe '#count' do
        it "manufactures a count aggregation" do
          @attribute1.count.should == Aggregation.new(@attribute1, "COUNT")
        end
      end
    
      describe '#sum' do
        it "manufactures a sum aggregation" do
          @attribute1.sum.should == Aggregation.new(@attribute1, "SUM")
        end
      end
    
      describe '#maximum' do
        it "manufactures a maximum aggregation" do
          @attribute1.maximum.should == Aggregation.new(@attribute1, "MAX")
        end
      end
    
      describe '#minimum' do
        it "manufactures a minimum aggregation" do
          @attribute1.minimum.should == Aggregation.new(@attribute1, "MIN")
        end
      end
    
      describe '#average' do
        it "manufactures an average aggregation" do
          @attribute1.average.should == Aggregation.new(@attribute1, "AVG")
        end
      end 
    end
  end
end