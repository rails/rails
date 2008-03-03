require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe RelationInclusion do
    before do
      users = Table.new(:users)
      @relation = users.project(users[:id])
      @attribute = @relation[:id]
    end
  
    describe RelationInclusion, '#to_sql' do
      it "manufactures subselect sql" do
        # remove when sufficient coverage of sql strategies exists
        RelationInclusion.new(@attribute, @relation).to_sql.should be_like("
          `users`.`id` IN (SELECT `users`.`id` FROM `users`)
        ")
      end
    end
  end
end