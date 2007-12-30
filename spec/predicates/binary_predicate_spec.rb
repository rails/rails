require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe BinaryPredicate do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute1 = Attribute.new(@relation1, :attribute_name)
    @attribute2 = Attribute.new(@relation2, :attribute_name)
  end
  
  describe BinaryPredicate, '#initialize' do
    it "requires that both columns come from the same relation" do
      pending
    end
  end
  
  describe BinaryPredicate, '==' do
    before do
      class ConcreteBinaryPredicate < BinaryPredicate
      end
    end
    
    it "obtains if attribute1 and attribute2 are identical" do
      BinaryPredicate.new(@attribute1, @attribute2).should == BinaryPredicate.new(@attribute1, @attribute2)
      BinaryPredicate.new(@attribute1, @attribute2).should_not == BinaryPredicate.new(@attribute1, @attribute1)
    end
    
    it "obtains if the concrete type of the BinaryPredicates are identical" do
      ConcreteBinaryPredicate.new(@attribute1, @attribute2).should == ConcreteBinaryPredicate.new(@attribute1, @attribute2)
      BinaryPredicate.new(@attribute1, @attribute2).should_not == ConcreteBinaryPredicate.new(@attribute1, @attribute2)
    end
  end
end