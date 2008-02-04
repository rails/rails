require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Attribute do
    before do
      @relation1 = Table.new(:foo)
      @relation2 = Table.new(:bar)
    end
  
    describe Attribute::Transformations do
      before do
        @attribute = Attribute.new(@relation1, :id)
      end
      
      describe '#as' do
        it "manufactures an aliased attributed" do
          @attribute.as(:alias).should == Attribute.new(@relation1, @attribute.name, :alias, @attribute)
        end
      end
    
      describe '#substitute' do
        it "manufactures an attribute with the relation substituted" do
          @attribute.substitute(@relation2).should == Attribute.new(@relation2, @attribute.name, nil, @attribute)
        end
      end
    
      describe '#qualify' do
        it "manufactures an attribute aliased with that attributes qualified name" do
          @attribute.qualify.should == Attribute.new(@attribute.relation, @attribute.name, @attribute.qualified_name, @attribute)
        end
      end
      
      describe '#to_attribute' do
        it "returns self" do
          @attribute.to_attribute.should == @attribute
        end
      end
    end
    
    describe '#qualified_name' do
      it "manufactures an attribute name prefixed with the relation's name" do
        Attribute.new(@relation1, :id).qualified_name.should == 'foo.id'
      end
    end
  
    describe '==' do
      it "obtains if the relation and attribute name are identical" do
        Attribute.new(@relation1, :name).should == Attribute.new(@relation1, :name)
        Attribute.new(@relation1, :name).should_not == Attribute.new(@relation1, :another_name)
        Attribute.new(@relation1, :name).should_not == Attribute.new(@relation2, :name)
        Attribute.new(@relation1, :name).should_not == Expression.new(Attribute.new(@relation1, :name), "SUM")
      end
    end
    
    describe '#to_sql' do
      it "needs to test prefix_for" do
        pending
      end
      
      describe Sql::Strategy do
        it "manufactures sql without an alias if the strategy is Predicate" do
          Attribute.new(@relation1, :name, :alias).to_sql(Sql::Predicate.new).should be_like("`foo`.`name`")
        end
      
        it "manufactures sql with an alias if the strategy is Projection" do
          Attribute.new(@relation1, :name, :alias).to_sql(Sql::Projection.new).should be_like("`foo`.`name` AS 'alias'")
        end
      end
    end
  
    describe Attribute::Predications do
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
  
    describe Attribute::Expressions do
      before do
        @attribute1 = Attribute.new(@relation1, :name)    
      end
    
      describe '#count' do
        it "manufactures a count Expression" do
          @attribute1.count.should == Expression.new(@attribute1, "COUNT")
        end
      end
    
      describe '#sum' do
        it "manufactures a sum Expression" do
          @attribute1.sum.should == Expression.new(@attribute1, "SUM")
        end
      end
    
      describe '#maximum' do
        it "manufactures a maximum Expression" do
          @attribute1.maximum.should == Expression.new(@attribute1, "MAX")
        end
      end
    
      describe '#minimum' do
        it "manufactures a minimum Expression" do
          @attribute1.minimum.should == Expression.new(@attribute1, "MIN")
        end
      end
    
      describe '#average' do
        it "manufactures an average Expression" do
          @attribute1.average.should == Expression.new(@attribute1, "AVG")
        end
      end 
    end
  end
end