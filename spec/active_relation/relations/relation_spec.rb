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
      @relation1[:id].should be_kind_of(Attribute)
    end
    
    it "manufactures a range relation when given a range" do
      @relation1[1..2].should be_kind_of(RangeRelation)
    end
  end
  
  describe '#include?' do
    it "manufactures an inclusion predicate" do
      @relation1.include?(@attribute1).should be_kind_of(RelationInclusionPredicate)
    end
  end

  describe 'read operations' do
    describe 'joins' do
      describe '<=>' do
        it "manufactures an inner join operation between those two relations" do
          (@relation1 <=> @relation2).should be_kind_of(InnerJoinOperation)
        end
      end
    
      describe '<<' do
        it "manufactures a left outer join operation between those two relations" do
          (@relation1 << @relation2).should be_kind_of(LeftOuterJoinOperation)
        end      
      end
    end
  
    describe '#project' do
      it "collapses identical projections" do
        pending
      end
    
      it "manufactures a projection relation" do
        @relation1.project(@attribute1, @attribute2).should be_kind_of(ProjectionRelation)
      end
    end
  
    describe '#rename' do
      it "manufactures a rename relation" do
        @relation1.rename(@attribute1, :foo).should be_kind_of(RenameRelation)
      end
    end
  
    describe '#select' do
      before do
        @predicate = EqualityPredicate.new(@attribute1, @attribute2)
      end
    
      it "manufactures a selection relation" do
        @relation1.select(@predicate).should be_kind_of(SelectionRelation)
      end
    
      it "accepts arbitrary strings" do
        @relation1.select("arbitrary").should be_kind_of(SelectionRelation)
      end
    end
  
    describe '#order' do
      it "manufactures an order relation" do
        @relation1.order(@attribute1, @attribute2).should be_kind_of(OrderRelation)
      end
    end
  end
  
  describe 'write operations' do
    describe '#delete' do
      it 'manufactures a deletion relation' do
        @relation1.delete.should be_kind_of(DeletionRelation)
      end
    end
    
    describe '#insert' do
      it 'manufactures an insertion relation' do
        @relation1.insert(record = {:id => 1}).should be_kind_of(InsertionRelation)
      end
    end
  end
end