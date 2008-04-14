require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Deletion do
    before do
      @relation = Table.new(:users)
    end
  
    describe '#to_sql' do
      it 'manufactures sql deleting a table relation' do
        Deletion.new(@relation).to_sql.should be_like("
          DELETE
          FROM `users`
        ")
      end
    
      it 'manufactures sql deleting a selection relation' do
        Deletion.new(@relation.select(@relation[:id].eq(1))).to_sql.should be_like("
          DELETE
          FROM `users`
          WHERE `users`.`id` = 1
        ")
      end
      
      it "manufactures sql deleting a ranged relation" do
        pending do
          Deletion.new(@relation.take(1)).to_sql.should be_like("
            DELETE
            FROM `users`
            LIMIT 1
          ")
        end
      end
    end
    
    describe '#call' do
      it 'executes a delete on the connection' do
        deletion = Deletion.new(@relation)
        mock(connection = Object.new).delete(deletion.to_sql)
        deletion.call(connection)
      end
    end
  end
end