require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Join do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end

    describe '==' do
      before do
        @another_predicate = @relation1[:id].eq(1)
        @another_relation = Table.new(:cameras)
      end
      
      it 'obtains if the two relations and the predicate are identical' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).should == Join.new("INNER JOIN", @relation1, @relation2, @predicate)
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).should_not == Join.new("INNER JOIN", @relation1, @another_relation, @predicate)
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).should_not == Join.new("INNER JOIN", @relation1, @relation2, @another_predicate)
      end
  
      it 'is commutative on the relations' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).should == Join.new("INNER JOIN", @relation2, @relation1, @predicate)
      end
    end
    
    describe 'hashing' do
      it 'implements hash equality' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate) \
          .should hash_the_same_as(Join.new("INNER JOIN", @relation1, @relation2, @predicate))
      end
    end
    
    describe '#engine' do
      it "delegates to a relation's engine" do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).engine.should == @relation1.engine
      end
    end
    
    describe 'when joining simple relations' do
      describe '#attributes' do
        it 'combines the attributes of the two relations' do
          join = Join.new("INNER JOIN", @relation1, @relation2, @predicate)
          join.attributes.should ==
            (@relation1.attributes + @relation2.attributes).collect { |a| a.bind(join) }
        end
      end

      describe '#to_sql' do
        it 'manufactures sql joining the two tables on the predicate' do
          Join.new("INNER JOIN", @relation1, @relation2, @predicate).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
            FROM `users`
              INNER JOIN `photos` ON `users`.`id` = `photos`.`user_id`
          ")
        end

        it 'manufactures sql joining the two tables, merging any selects' do
          Join.new("INNER JOIN", @relation1.select(@relation1[:id].eq(1)),
                                 @relation2.select(@relation2[:id].eq(2)), @predicate).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
            FROM `users`
              INNER JOIN `photos` ON `users`.`id` = `photos`.`user_id`
            WHERE `users`.`id` = 1
              AND `photos`.`id` = 2
          ")
        end
      end
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
    
    describe 'when joining a relation to itself' do
      before do
        @aliased_relation = @relation1.alias
        @predicate = @relation1[:id].eq(@aliased_relation[:id])
      end      
      
      describe 'when joining the same relation to itself' do
        describe '#to_sql' do
          it 'manufactures sql aliasing the table and attributes properly in the join predicate and the where clause' do
            @relation1.join(@aliased_relation).on(@predicate).to_sql.should be_like("
              SELECT `users`.`id`, `users`.`name`, `users_2`.`id`, `users_2`.`name`
              FROM `users`
                INNER JOIN `users` AS `users_2`
                  ON `users`.`id` = `users_2`.`id`
            ")
          end
          
          describe 'when joining with a selection on the same relation' do
            it 'manufactures sql aliasing the tables properly' do
              @relation1                                                      \
                .join(@aliased_relation.select(@aliased_relation[:id].eq(1))) \
                  .on(@predicate)                                             \
              .to_sql.should be_like("
                SELECT `users`.`id`, `users`.`name`, `users_2`.`id`, `users_2`.`name`
                FROM `users`
                  INNER JOIN `users` AS `users_2`
                    ON `users`.`id` = `users_2`.`id`
                WHERE `users_2`.`id` = 1
              ")
            end
          end
          
          describe 'when joining the same relation to itself multiple times' do
            before do
              @relation2 = @relation1.alias
              @relation3 = @relation1.alias
            end
            
            describe 'when joining left-associatively' do
              it 'manufactures sql aliasing the tables properly' do
                @relation1 \
                  .join(@relation2.join(@relation3).on(@relation2[:id].eq(@relation3[:id]))) \
                    .on(@relation1[:id].eq(@relation2[:id]))                                 \
                .to_sql.should be_like("
                  SELECT `users`.`id`, `users`.`name`, `users_2`.`id`, `users_2`.`name`, `users_3`.`id`, `users_3`.`name`
                  FROM `users`
                    INNER JOIN `users` AS `users_2`
                      ON `users`.`id` = `users_2`.`id`
                    INNER JOIN `users` AS `users_3`
                      ON `users_2`.`id` = `users_3`.`id`
                ")
              end
            end
            
            describe 'when joining right-associatively' do
              it 'manufactures sql aliasing the tables properly' do
                @relation1                                                    \
                  .join(@relation2).on(@relation1[:id].eq(@relation2[:id]))   \
                  .join(@relation3).on(@relation2[:id].eq(@relation3[:id]))   \
                .to_sql.should be_like("
                  SELECT `users`.`id`, `users`.`name`, `users_2`.`id`, `users_2`.`name`, `users_3`.`id`, `users_3`.`name`
                  FROM `users`
                    INNER JOIN `users` AS `users_2`
                      ON `users`.`id` = `users_2`.`id`
                    INNER JOIN `users` AS `users_3`
                      ON `users_2`.`id` = `users_3`.`id`
                ")
              end
            end
          end
        end
        
        describe '[]' do
          describe 'when given an attribute belonging to both sub-relations' do
            it 'disambiguates the relation that serves as the ancestor to the attribute' do
              relation = @relation1.join(@aliased_relation).on(@predicate)
              relation[@relation1[:id]].ancestor.should == @relation1[:id]
              relation[@aliased_relation[:id]].ancestor.should == @aliased_relation[:id]
            end
          end
        end
      end
    end
    
    describe 'when joining with a string' do
      it "passes the string through to the where clause" do
        Join.new("INNER JOIN asdf ON fdsa", @relation1).to_sql.should be_like("
          SELECT `users`.`id`, `users`.`name`
          FROM `users`
            INNER JOIN asdf ON fdsa
        ")
      end
    end
  end
end