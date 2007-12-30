require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Attribute do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
  end
  
  describe Attribute, '#eql?' do
    it "obtains if the relation and attribute name are identical" do
      Attribute.new(@relation1, :attribute_name).should be_eql(Attribute.new(@relation1, :attribute_name))
      Attribute.new(@relation1, :attribute_name).should_not be_eql(Attribute.new(@relation1, :another_attribute_name))
      Attribute.new(@relation1, :attribute_name).should_not be_eql(Attribute.new(@relation2, :attribute_name))
    end
  end
  
  describe Attribute, 'predications' do
    before do
      @attribute1 = Attribute.new(@relation1, :attribute_name)
      @attribute2 = Attribute.new(@relation2, :attribute_name)
    end
    
    describe Attribute, '==' do
      it "manufactures an equality predicate" do
        (@attribute1 == @attribute2).should == EqualityPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe Attribute, '<' do
      it "manufactures a less-than predicate" do
        (@attribute1 < @attribute2).should == LessThanPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe Attribute, '<=' do
      it "manufactures a less-than or equal-to predicate" do
        (@attribute1 <= @attribute2).should == LessThanOrEqualToPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe Attribute, '>' do
      it "manufactures a greater-than predicate" do
        (@attribute1 > @attribute2).should == GreaterThanPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe Attribute, '>=' do
      it "manufactures a greater-than or equal to predicate" do
        (@attribute1 >= @attribute2).should == GreaterThanOrEqualToPredicate.new(@attribute1, @attribute2)
      end
    end
    
    describe Attribute, '=~' do
      it "manufactures a match predicate" do
        (@attribute1 =~ /.*/).should == MatchPredicate.new(@attribute1, @attribute2)
      end
    end
    
  end
end
