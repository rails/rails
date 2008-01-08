require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe Relation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute1 = Attribute.new(@relation1, :id)
    @attribute2 = Attribute.new(@relation1, :name)
  end
  
  describe '[]' do
    it "manufactures an attribute when given a symbol" do
      @relation1[:id].should be_eql(Attribute.new(@relation1, :id))
    end
    
    it "manufactures a range relation when given a range" do
      @relation1[1..2].should == RangeRelation.new(@relation1, 1..2)
    end
  end
  
  describe '#include?' do
    it "manufactures an inclusion predicate" do
      @relation1.include?(@attribute1).should == RelationInclusionPredicate.new(@attribute1, @relation1)
    end
  end

  describe 'read operations' do
    describe 'joins' do
      describe '<=>' do
        it "manufactures an inner join operation between those two relations" do
          (@relation1 <=> @relation2).should == InnerJoinOperation.new(@relation1, @relation2)
        end
      end
    
      describe '<<' do
        it "manufactures a left outer join operation between those two relations" do
          (@relation1 << @relation2).should == LeftOuterJoinOperation.new(@relation1, @relation2)
        end      
      end
    end
  
    describe '#project' do
      it "collapses identical projections" do
        pending
      end
    
      it "manufactures a projection relation" do
        @relation1.project(@attribute1, @attribute2).should == ProjectionRelation.new(@relation1, @attribute1, @attribute2)
      end
    end
  
    describe '#rename' do
      it "manufactures a rename relation" do
        @relation1.rename(@attribute1, :foo).should == RenameRelation.new(@relation1, @attribute1 => :foo)
      end
    end
  
    describe '#select' do
      before do
        @predicate = EqualityPredicate.new(@attribute1, @attribute2)
      end
    
      it "manufactures a selection relation" do
        @relation1.select(@predicate).should == SelectionRelation.new(@relation1, @predicate)
      end
    
      it "accepts arbitrary strings" do
        @relation1.select("arbitrary").should == SelectionRelation.new(@relation1, "arbitrary")
      end
    end
  
    describe '#order' do
      it "manufactures an order relation" do
        @relation1.order(@attribute1, @attribute2).should == OrderRelation.new(@relation1, @attribute1, @attribute2)
      end
    end
  end
  
  describe 'write operations' do
    describe '#delete' do
      it 'manufactures a deletion relation' do
        @relation1.delete.should == DeletionRelation.new(@relation1)
      end
    end
    
    describe '#insert' do
      it 'manufactures an insertion relation' do
        @relation1.insert(tuple = {:id => 1}).should == InsertionRelation.new(@relation1, tuple)
      end
    end
  end
end