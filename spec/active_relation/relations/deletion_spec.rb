require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Relations::Deletion do
  before do
    @relation = ActiveRelation::Relations::Table.new(:users)
  end
  
  describe '#to_sql' do
    it 'manufactures sql deleting a table relation' do
      ActiveRelation::Relations::Deletion.new(@relation).to_sql.should be_like("""
        DELETE
        FROM `users`
      """)
    end
    
    it 'manufactures sql deleting a selection relation' do
      ActiveRelation::Relations::Deletion.new(@relation.select(@relation[:id].equals(1))).to_sql.should be_like("""
        DELETE
        FROM `users`
        WHERE `users`.`id` = 1
      """)
    end
  end
end