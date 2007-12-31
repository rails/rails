require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe 'between two relations' do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
  end
  
  describe '==' do
    it "obtains if the relations of both joins are identical" do
      JoinOperation.new(@relation1, @relation2).should == JoinOperation.new(@relation1, @relation2)
      JoinOperation.new(@relation1, @relation2).should_not == JoinOperation.new(@relation1, @relation1)
    end
  
    it "is commutative on the relations" do
      JoinOperation.new(@relation1, @relation2).should == JoinOperation.new(@relation2, @relation1)
    end
  end

  describe 'on' do
    before do
      @predicate = Predicate.new
      @join_operation = JoinOperation.new(@relation1, @relation2)
      class << @join_operation
        def relation_class
          JoinRelation
        end
      end
    end
    
    it "manufactures a join relation of the appropriate type" do
      @join_operation.on(@predicate).should == JoinRelation.new(@relation1, @relation2, @predicate)
    end
  end
end