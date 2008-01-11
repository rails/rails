require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Predicates::RelationInclusion do
  before do
    @relation1 = ActiveRelation::Relations::Table.new(:foo)
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
    @attribute = @relation1[:baz]
  end
  
  describe ActiveRelation::Predicates::RelationInclusion, '==' do    
    it "obtains if attribute1 and attribute2 are identical" do
      ActiveRelation::Predicates::RelationInclusion.new(@attribute, @relation1).should == ActiveRelation::Predicates::RelationInclusion.new(@attribute, @relation1)
      ActiveRelation::Predicates::RelationInclusion.new(@attribute, @relation1).should_not == ActiveRelation::Predicates::RelationInclusion.new(@attribute, @relation2)
    end
  end
end