require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe Relation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
  end
  
  describe Relation, '*' do
    it "manufactures a JoinOperation between those two relations" do
      (@relation1 * @relation2).should == JoinOperation.new(@relation1, @relation2)
    end
  end
  
  describe Relation, '[]' do
    it "manufactures a attribute" do
      @relation1[:id].should be_eql(Attribute.new(@relation1, :id))
    end
    
    it "raises an error if the named attribute is not part of the relation" do
      pending
    end
  end
  
  describe Relation, '#include?' do
    before do
      @attribute = Attribute.new(@relation1, :id)
    end
    
    it "manufactures an inclusion predicate" do
      @relation1.include?(@attribute).should == RelationInclusionPredicate.new(@attribute, @relation1)
    end
  end
  
  describe Relation, '#project' do
    before do
      @attribute1 = Attribute.new(@relation1, :id)
      @attribute2 = Attribute.new(@relation1, :name)
    end
    
    it "only allows projecting attributes in the relation" do
      pending
    end
    
    it "collapses identical projections" do
      pending
    end
    
    it "manufactures a projected relation" do
      @relation1.project(@attribute1, @attribute2).should == ProjectedRelation(@relation1, @attribute1, @attribute2)
    end
  end
  
  describe Relation, '#select' do
    before do
      @predicate = EqualityPredicate.new()
    end
    
    it "manufactures a selected relation" do
      @relation1.select(@attribute1, @attribute2).should == SelectedRelation(@relation1, @attribute1, @attribute2)
    end
  end 
end