require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe EqualityPredicate do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute1 = Attribute.new(@relation1, :name)
    @attribute2 = Attribute.new(@relation2, :name)
  end
  
  describe '==' do 
    it "obtains if attribute1 and attribute2 are identical" do
      EqualityPredicate.new(@attribute1, @attribute2).should == EqualityPredicate.new(@attribute1, @attribute2)
      EqualityPredicate.new(@attribute1, @attribute2).should_not == EqualityPredicate.new(@attribute1, @attribute1)
    end
    
    it "obtains if the concrete type of the predicates are identical" do
      EqualityPredicate.new(@attribute1, @attribute2).should_not == BinaryPredicate.new(@attribute1, @attribute2)
    end
    
    it "is commutative on the attributes" do
      EqualityPredicate.new(@attribute1, @attribute2).should == EqualityPredicate.new(@attribute2, @attribute1)
    end
  end
end