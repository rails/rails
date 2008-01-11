require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Predicates::Equality do
  before do
    @relation1 = ActiveRelation::Relations::Table.new(:foo)
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
    @attribute1 = ActiveRelation::Primitives::Attribute.new(@relation1, :name)
    @attribute2 = ActiveRelation::Primitives::Attribute.new(@relation2, :name)
  end
  
  describe '==' do 
    it "obtains if attribute1 and attribute2 are identical" do
      ActiveRelation::Predicates::Equality.new(@attribute1, @attribute2).should == ActiveRelation::Predicates::Equality.new(@attribute1, @attribute2)
      ActiveRelation::Predicates::Equality.new(@attribute1, @attribute2).should_not == ActiveRelation::Predicates::Equality.new(@attribute1, @attribute1)
    end
    
    it "obtains if the concrete type of the predicates are identical" do
      ActiveRelation::Predicates::Equality.new(@attribute1, @attribute2).should_not == ActiveRelation::Predicates::Binary.new(@attribute1, @attribute2)
    end
    
    it "is commutative on the attributes" do
      ActiveRelation::Predicates::Equality.new(@attribute1, @attribute2).should == ActiveRelation::Predicates::Equality.new(@attribute2, @attribute1)
    end
  end
end