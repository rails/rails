require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Join do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end
    
    describe 'when a compound contains a join' do
      describe '#to_sql' do
        describe 'when the compound is a select' do
          it 'manufactures sql disambiguating the tables' do
            @relation1                        \
              .select(@relation1[:id].eq(1))  \
              .join(@relation2)               \
                .on(@predicate)               \
              .select(@relation1[:id].eq(1))  \
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
        
        describe 'when the compound is a group' do
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