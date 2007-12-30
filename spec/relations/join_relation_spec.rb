require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe JoinRelation, 'between two relations' do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @predicate = Predicate.new
  end
  
  describe JoinRelation, '==' do
    it "obtains if the two relations and the predicate are identical" do
      JoinRelation.new(@relation1, @relation2, @predicate).should == JoinRelation.new(@relation1, @relation2, @predicate)
      JoinRelation.new(@relation1, @relation2, @predicate).should_not == JoinRelation.new(@relation1, @relation1, @predicate)
    end
  
    it "is commutative on the relations" do
      JoinRelation.new(@relation1, @relation2, @predicate).should == JoinRelation.new(@relation2, @relation1, @predicate)
    end
  end
end