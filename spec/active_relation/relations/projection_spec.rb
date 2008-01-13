require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Relations::Projection do
  before do
    @relation1 = ActiveRelation::Relations::Table.new(:foo)
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
    @attribute1 = @relation1[:id]
    @attribute2 = @relation2[:id]
  end
  
  describe '==' do
    it "obtains if the relations and attributes are identical" do
      ActiveRelation::Relations::Projection.new(@relation1, @attribute1, @attribute2).should == ActiveRelation::Relations::Projection.new(@relation1, @attribute1, @attribute2)
      ActiveRelation::Relations::Projection.new(@relation1, @attribute1).should_not == ActiveRelation::Relations::Projection.new(@relation2, @attribute1)
      ActiveRelation::Relations::Projection.new(@relation1, @attribute1).should_not == ActiveRelation::Relations::Projection.new(@relation1, @attribute2)
    end
  end
  
  describe '#qualify' do
    it "distributes over the relation and attributes" do
      ActiveRelation::Relations::Projection.new(@relation1, @attribute1).qualify. \
        should == ActiveRelation::Relations::Projection.new(@relation1.qualify, @attribute1.qualify)
    end
  end
  
  describe '#to_sql' do
    it "manufactures sql with a limited select clause" do
      ActiveRelation::Relations::Projection.new(@relation1, @attribute1).to_sql.should be_like("""
        SELECT `foo`.`id`
        FROM `foo`
      """)
    end
  end
end