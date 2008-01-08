require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe DeletionRelation do
  before do
    @relation = TableRelation.new(:users)
  end
  
  describe '#to_sql' do
    it 'manufactures sql deleting a table relation' do
      DeletionRelation.new(@relation).to_sql.should be_like("""
        DELETE
        FROM `users`
      """)
    end
    
    it 'manufactures sql deleting a selection relation' do
      DeletionRelation.new(@relation.select(@relation[:id] == 1)).to_sql.should be_like("""
        DELETE
        FROM `users`
        WHERE `users`.`id` = 1
      """)
    end
  end
end