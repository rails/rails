require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Update do
    before do
      @relation = Table.new(:users)
    end
  
    describe '#to_sql' do
      it "manufactures sql updating attributes when given multiple attributes" do
        Update.new(@relation, @relation[:id] => 1, @relation[:name] => "nick").to_sql.should be_like("
          UPDATE `users`
          SET `users`.`id` = 1, `users`.`name` = 'nick'
        ")
      end
      
      it "manufactures sql updating attributes when given a ranged relation" do
        pending do
          Update.new(@relation.take(1), @relation[:name] => "nick").to_sql.should be_like("
            UPDATE `users`
            SET `users`.`name` = 'nick'
            LIMIT 1
          ")
        end
      end
      
      describe 'when given values whose types correspond to the types of the attributes' do
        before do
          @update = Update.new(@relation, @relation[:name] => "nick")
        end
        
        it 'manufactures sql updating attributes' do
          @update.to_sql.should be_like("
            UPDATE `users`
            SET `users`.`name` = 'nick'
          ")
        end
      end

      describe 'when given values whose types differ from from the types of the attributes' do
        before do
          @update = Update.new(@relation, @relation[:id] => '1-asdf')
        end
        
        it 'manufactures sql updating attributes' do
          @update.to_sql.should be_like("
            UPDATE `users`
            SET `users`.`id` = 1
          ")
        end
      end
            
      describe 'when the relation is a selection' do
        before do
          @update = Update.new(
            @relation.select(@relation[:id].eq(1)),
            @relation[:name] => "nick"
          )
        end
        
        it 'manufactures sql updating a selection relation' do
          @update.to_sql.should be_like("
            UPDATE `users`
            SET `users`.`name` = 'nick'
            WHERE `users`.`id` = 1
          ")
        end
      end
    end
    
    describe '#call' do
      before do
        @update = Update.new(@relation, @relation[:name] => "nick")
      end
      
      it 'executes an update on the connection' do
        mock(connection = Object.new).update(@update.to_sql)
        @update.call(connection)
      end
    end
    
  end
end