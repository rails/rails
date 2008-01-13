require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Predicates::RelationInclusion do
  before do
    foo = ActiveRelation::Relations::Table.new(:foo)
    @relation1 = foo.project(foo[:id])
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
    @attribute = @relation1[:id]
  end
  
  describe ActiveRelation::Predicates::RelationInclusion, '==' do    
    it "obtains if attribute1 and attribute2 are identical" do
      ActiveRelation::Predicates::RelationInclusion.new(@attribute, @relation1).should == ActiveRelation::Predicates::RelationInclusion.new(@attribute, @relation1)
      ActiveRelation::Predicates::RelationInclusion.new(@attribute, @relation1).should_not == ActiveRelation::Predicates::RelationInclusion.new(@attribute, @relation2)
    end
  end
  
  describe ActiveRelation::Predicates::RelationInclusion, '#to_sql' do
    it "manufactures subselect sql" do
      ActiveRelation::Predicates::RelationInclusion.new(@attribute, @relation1).to_sql.should be_like("""
        `foo`.`id` IN (SELECT `foo`.`id` FROM `foo`)
      """)
    end
  end
end