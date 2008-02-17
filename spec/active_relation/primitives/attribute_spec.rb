require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Attribute do
    before do
      @relation = Table.new(:users)
    end
  
    describe Attribute::Transformations do
      before do
        @attribute = Attribute.new(@relation, :id)
      end
      
      describe '#as' do
        it "manufactures an aliased attributed" do
          @attribute.as(:alias).should == Attribute.new(@relation, @attribute.name, :alias, @attribute)
        end
      end
    
      describe '#bind' do
        it "manufactures an attribute with the relation bound and self as an ancestor" do
          derived_relation = @relation.select(@relation[:id].equals(1))
          @attribute.bind(derived_relation).should == Attribute.new(derived_relation, @attribute.name, nil, @attribute)
        end
        
        it "returns self if the substituting to the same relation" do
          @attribute.bind(@relation).should == @attribute
        end
      end
    
      describe '#qualify' do
        it "manufactures an attribute aliased with that attribute's qualified name" do
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
        Attribute.new(@relation, :id).qualified_name.should == 'users.id'
      end
    end
    
    describe Attribute::Congruence do
      describe '=~' do
        it "obtains if the attributes are identical" do
          Attribute.new(@relation, :name).should =~ Attribute.new(@relation, :name)
        end
      
        it "obtains if the attributes have an overlapping history" do
          Attribute.new(@relation, :name, nil, Attribute.new(@relation, :name)).should =~ Attribute.new(@relation, :name)
          Attribute.new(@relation, :name).should =~ Attribute.new(@relation, :name, nil, Attribute.new(@relation, :name))
        end
      end
    end
    
    describe '#to_sql' do
      describe Sql::Strategy do
        it "manufactures sql without an alias if the strategy is Predicate" do
          Attribute.new(@relation, :name, :alias).to_sql(Sql::Predicate.new).should be_like("`users`.`name`")
        end
      
        it "manufactures sql with an alias if the strategy is Projection" do
          Attribute.new(@relation, :name, :alias).to_sql(Sql::Projection.new).should be_like("`users`.`name` AS 'alias'")
        end
      end
    end
  
    describe Attribute::Predications do
      before do
        @attribute = Attribute.new(@relation, :name)
      end
    
      describe '#equals' do
        it "manufactures an equality predicate" do
          @attribute.equals('name').should == Equality.new(@attribute, 'name')
        end
      end
    
      describe '#less_than' do
        it "manufactures a less-than predicate" do
          @attribute.less_than(10).should == LessThan.new(@attribute, 10)
        end
      end
    
      describe '#less_than_or_equal_to' do
        it "manufactures a less-than or equal-to predicate" do
          @attribute.less_than_or_equal_to(10).should == LessThanOrEqualTo.new(@attribute, 10)
        end
      end
    
      describe '#greater_than' do
        it "manufactures a greater-than predicate" do
          @attribute.greater_than(10).should == GreaterThan.new(@attribute, 10)
        end
      end
    
      describe '#greater_than_or_equal_to' do
        it "manufactures a greater-than or equal-to predicate" do
          @attribute.greater_than_or_equal_to(10).should == GreaterThanOrEqualTo.new(@attribute, 10)
        end
      end
    
      describe '#matches' do
        it "manufactures a match predicate" do
          @attribute.matches(/.*/).should == Match.new(@attribute, /.*/)
        end
      end
    end
  
    describe Attribute::Expressions do
      before do
        @attribute = Attribute.new(@relation, :name)    
      end
    
      describe '#count' do
        it "manufactures a count Expression" do
          @attribute.count.should == Expression.new(@attribute, "COUNT")
        end
      end
    
      describe '#sum' do
        it "manufactures a sum Expression" do
          @attribute.sum.should == Expression.new(@attribute, "SUM")
        end
      end
    
      describe '#maximum' do
        it "manufactures a maximum Expression" do
          @attribute.maximum.should == Expression.new(@attribute, "MAX")
        end
      end
    
      describe '#minimum' do
        it "manufactures a minimum Expression" do
          @attribute.minimum.should == Expression.new(@attribute, "MIN")
        end
      end
    
      describe '#average' do
        it "manufactures an average Expression" do
          @attribute.average.should == Expression.new(@attribute, "AVG")
        end
      end 
    end
  end
end