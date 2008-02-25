require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Equality do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @attribute1 = @relation1[:name]
      @attribute2 = @relation2[:name]
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
  end
end