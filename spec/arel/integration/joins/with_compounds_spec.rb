require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Join do
    before do
      @relation1 = Arel(:users)
      @relation2 = Arel(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end
    
    describe '#to_sql' do
      describe 'when the join contains a where' do
        describe 'and the where is given a string' do
          it 'does not escape the string' do
            @relation1                          \
              .join(@relation2.where("asdf"))   \
                .on(@predicate)                 \
            .to_sql.should be_like("
              SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
              FROM `users`
              INNER JOIN `photos`
                ON `users`.`id` = `photos`.`user_id` AND asdf
            ")
          end
        end
      end
    
      describe 'when a compound contains a join' do
        describe 'and the compound is a where' do
          it 'manufactures sql disambiguating the tables' do
            @relation1                        \
              .where(@relation1[:id].eq(1))   \
              .join(@relation2)               \
                .on(@predicate)               \
              .where(@relation1[:id].eq(1))   \
            .to_sql.should be_like("
              SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
              FROM `users`
              INNER JOIN `photos`
                ON `users`.`id` = `photos`.`user_id`
              WHERE `users`.`id` = 1
                AND `users`.`id` = 1
            ")
          end
        end
        
        describe 'and the compound is a group' do
          it 'manufactures sql disambiguating the tables' do
            @relation1                \
              .join(@relation2)       \
                .on(@predicate)       \
              .group(@relation1[:id]) \
            .to_sql.should be_like("
              SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
              FROM `users`
              INNER JOIN `photos`
                ON `users`.`id` = `photos`.`user_id`
              GROUP BY `users`.`id`
            ")
          end
        end
      end
    end
  end
end