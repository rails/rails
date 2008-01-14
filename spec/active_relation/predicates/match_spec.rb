require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe RelationInclusion do
    before do
      @relation1 = Table.new(:foo)
      @relation2 = Table.new(:bar)
      @attribute = @relation1[:baz]
    end
  
    describe RelationInclusion, '==' do    
      it "obtains if attribute1 and attribute2 are identical" do
        RelationInclusion.new(@attribute, @relation1).should == RelationInclusion.new(@attribute, @relation1)
        RelationInclusion.new(@attribute, @relation1).should_not == RelationInclusion.new(@attribute, @relation2)
      end
    end
  end
end