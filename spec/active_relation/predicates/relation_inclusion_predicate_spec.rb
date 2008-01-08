require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe RelationInclusionPredicate do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute = @relation1[:baz]
  end
  
  describe RelationInclusionPredicate, '==' do    
    it "obtains if attribute1 and attribute2 are identical" do
      RelationInclusionPredicate.new(@attribute, @relation1).should == RelationInclusionPredicate.new(@attribute, @relation1)
      RelationInclusionPredicate.new(@attribute, @relation1).should_not == RelationInclusionPredicate.new(@attribute, @relation2)
    end
  end
end