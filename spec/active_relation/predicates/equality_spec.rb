require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Equality do
    before do
      @relation1 = Table.new(:foo)
      @relation2 = Table.new(:bar)
      @attribute1 = Attribute.new(@relation1, :name)
      @attribute2 = Attribute.new(@relation2, :name)
    end
  
    describe '==' do 
      it "obtains if attribute1 and attribute2 are identical" do
        Equality.new(@attribute1, @attribute2).should == Equality.new(@attribute1, @attribute2)
        Equality.new(@attribute1, @attribute2).should_not == Equality.new(@attribute1, @attribute1)
      end
    
      it "obtains if the concrete type of the predicates are identical" do
        Equality.new(@attribute1, @attribute2).should_not == Binary.new(@attribute1, @attribute2)
      end
    
      it "is commutative on the attributes" do
        Equality.new(@attribute1, @attribute2).should == Equality.new(@attribute2, @attribute1)
      end
    end
  
    describe '#to_sql' do
    end
  end
end