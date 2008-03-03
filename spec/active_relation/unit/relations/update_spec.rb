require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Update do
    before do
      @relation = Table.new(:users)
    end
  
    describe '#to_sql' do
      it 'manufactures sql updating attributes' do
        Update.new(@relation, @relation[:name] => "nick".bind(@relation)).to_sql.should be_like("
          UPDATE `users`
          SET `users`.`name` = 'nick'
        ")
      end
      
      it 'manufactures sql updating a selection relation' do
        Update.new(@relation.select(@relation[:id].equals(1)), @relation[:name] => "nick".bind(@relation)).to_sql.should be_like("
          UPDATE `users`
          SET `users`.`name` = 'nick'
          WHERE `users`.`id` = 1
        ")
      end
    end
  end
end