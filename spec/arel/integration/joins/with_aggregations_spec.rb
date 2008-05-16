require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Join do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end
    
    describe 'when joining aggregated relations' do
      before do
        @aggregation = @relation2                                           \
          .group(@relation2[:user_id])                                      \
          .project(@relation2[:user_id], @relation2[:id].count.as(:cnt))    \
      end
      
      describe '#attributes' do
        it 'it transforms aggregate expressions into attributes' do
          join_with_aggregation = Join.new("INNER JOIN", @relation1, @aggregation, @predicate)
          join_with_aggregation.attributes.should ==
            (@relation1.attributes + @aggregation.attributes).collect(&:to_attribute).collect { |a| a.bind(join_with_aggregation) }
        end
      end
      
      describe '#to_sql' do
        describe 'with the aggregation on the right' do
          it 'manufactures sql joining the left table to a derived table' do
            Join.new("INNER JOIN", @relation1, @aggregation, @predicate).to_sql.should be_like("
              SELECT `users`.`id`, `users`.`name`, `photos_aggregation`.`user_id`, `photos_aggregation`.`cnt`
              FROM `users`
                INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photos_aggregation`
                  ON `users`.`id` = `photos_aggregation`.`user_id`
            ")
          end
        end

        describe 'with the aggregation on the left' do
          it 'manufactures sql joining the right table to a derived table' do
            Join.new("INNER JOIN", @aggregation, @relation1, @predicate).to_sql.should be_like("
              SELECT `photos_aggregation`.`user_id`, `photos_aggregation`.`cnt`, `users`.`id`, `users`.`name`
              FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photos_aggregation`
                INNER JOIN `users`
                  ON `users`.`id` = `photos_aggregation`.`user_id`
            ")
          end
        end

        describe 'when the aggration has a selection' do
          describe 'with the aggregation on the left' do
            it "manufactures sql keeping selects on the aggregation within the derived table" do
              Join.new("INNER JOIN", @relation1, @aggregation.select(@aggregation[:user_id].eq(1)), @predicate).to_sql.should be_like("
                SELECT `users`.`id`, `users`.`name`, `photos_aggregation`.`user_id`, `photos_aggregation`.`cnt`
                FROM `users`
                  INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` WHERE `photos`.`user_id` = 1 GROUP BY `photos`.`user_id`) AS `photos_aggregation`
                    ON `users`.`id` = `photos_aggregation`.`user_id`
              ")
            end
          end
          
          describe 'with the aggregation on the right' do
            it "manufactures sql keeping selects on the aggregation within the derived table" do
              Join.new("INNER JOIN", @aggregation.select(@aggregation[:user_id].eq(1)), @relation1, @predicate).to_sql.should be_like("
                SELECT `photos_aggregation`.`user_id`, `photos_aggregation`.`cnt`, `users`.`id`, `users`.`name`
                FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` WHERE `photos`.`user_id` = 1 GROUP BY `photos`.`user_id`) AS `photos_aggregation`
                  INNER JOIN `users`
                    ON `users`.`id` = `photos_aggregation`.`user_id`
              ")
            end
          end
        end
      end
    end
  end
end