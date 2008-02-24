require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe RelationInclusion do
    before do
      foo = Table.new(:foo)
      @relation1 = foo.project(foo[:id])
      @relation2 = Table.new(:bar)
      @attribute = @relation1[:id]
    end
  
    describe RelationInclusion, '==' do    
      it "obtains if attribute1 and attribute2 are identical" do
        RelationInclusion.new(@attribute, @relation1).should == RelationInclusion.new(@attribute, @relation1)
        RelationInclusion.new(@attribute, @relation1).should_not == RelationInclusion.new(@attribute, @relation2)
      end
    end
  
    describe RelationInclusion, '#to_sql' do
      it "manufactures subselect sql" do
        RelationInclusion.new(@attribute, @relation1).to_sql.should be_like("""
          `foo`.`id` IN (SELECT `foo`.`id` FROM `foo`)
        """)
      end
    end
  end
end