require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Relations::Base do
  before do
    @relation1 = ActiveRelation::Relations::Table.new(:foo)
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
    @attribute1 = ActiveRelation::Primitives::Attribute.new(@relation1, :id)
    @attribute2 = ActiveRelation::Primitives::Attribute.new(@relation1, :name)
  end
  
  describe '[]' do
    it "manufactures an attribute when given a symbol" do
      @relation1[:id].should == ActiveRelation::Primitives::Attribute.new(@relation1, :id)
    end
    
    it "manufactures a range relation when given a range" do
      @relation1[1..2].should == ActiveRelation::Relations::Range.new(@relation1, 1..2)
    end
  end
  
  describe '#include?' do
    it "manufactures an inclusion predicate" do
      @relation1.include?(@attribute1).should be_kind_of(ActiveRelation::Predicates::RelationInclusion)
    end
  end

  describe 'read operations' do
    describe 'joins' do
      before do
        @predicate = @relation1[:id].equals(@relation2[:id])
      end
      
      describe '#join' do
        it "manufactures an inner join operation between those two relations" do
          @relation1.join(@relation2).on(@predicate).should == ActiveRelation::Relations::Join.new("INNER JOIN", @relation1, @relation2, @predicate)
        end
      end
    
      describe '#outer_join' do
        it "manufactures a left outer join operation between those two relations" do
          @relation1.outer_join(@relation2).on(@predicate).should == ActiveRelation::Relations::Join.new("LEFT OUTER JOIN", @relation1, @relation2, @predicate)
        end      
      end
    end
  
    describe '#project' do
      it "collapses identical projections" do
        pending
      end
    
      it "manufactures a projection relation" do
        @relation1.project(@attribute1, @attribute2).should == ActiveRelation::Relations::Projection.new(@relation1, @attribute1, @attribute2)
      end
    end
    
    describe '#as' do
      it "manufactures an alias relation" do
        @relation1.as(:thucydides).should == ActiveRelation::Relations::Alias.new(@relation1, :thucydides)
      end
    end
  
    describe '#rename' do
      it "manufactures a rename relation" do
        @relation1.rename(@attribute1, :foo).should == ActiveRelation::Relations::Rename.new(@relation1, @attribute1 => :foo)
      end
    end
  
    describe '#select' do
      before do
        @predicate = ActiveRelation::Predicates::Equality.new(@attribute1, @attribute2)
      end
    
      it "manufactures a selection relation" do
        @relation1.select(@predicate).should == ActiveRelation::Relations::Selection.new(@relation1, @predicate)
      end
    
      it "accepts arbitrary strings" do
        @relation1.select("arbitrary").should == ActiveRelation::Relations::Selection.new(@relation1, "arbitrary")
      end
    end
  
    describe '#order' do
      it "manufactures an order relation" do
        @relation1.order(@attribute1, @attribute2).should be_kind_of(ActiveRelation::Relations::Order)
      end
    end
  end
  
  describe 'write operations' do
    describe '#delete' do
      it 'manufactures a deletion relation' do
        @relation1.delete.should be_kind_of(ActiveRelation::Relations::Deletion)
      end
    end
    
    describe '#insert' do
      it 'manufactures an insertion relation' do
        @relation1.insert(record = {:id => 1}).should be_kind_of(ActiveRelation::Relations::Insertion)
      end
    end
  end
  
  describe '#to_sql' do
    it "manufactures sql with scalar selects" do
      @relation1.as(:tobias).to_sql(:use_parens => true).should be_like("""
        (SELECT `foo`.`name`, `foo`.`id` FROM `foo`) AS tobias
      """)
    end
  end
end