require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Join do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @predicate = @relation1[:id].equals(@relation2[:user_id])
    end

    describe '==' do
      before do
        @another_predicate = @relation1[:id].equals(1)
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

    describe '#qualify' do
      it 'descends' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).qualify. \
          should == Join.new("INNER JOIN", @relation1, @relation2, @predicate).descend(&:qualify)
      end
    end
    
    describe '#descend' do
      it 'distributes over the relations and predicates' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).qualify. \
          should == Join.new("INNER JOIN", @relation1.qualify, @relation2.qualify, @predicate.qualify)
      end
    end

    describe '#prefix_for' do
      describe 'when the joined relations are simple' do
        it "returns the name of the relation containing the attribute" do
          Join.new("INNER JOIN", @relation1, @relation2, @predicate).prefix_for(@relation1[:id]) \
            .should == @relation1.prefix_for(@relation1[:id])
          Join.new("INNER JOIN", @relation1, @relation2, @predicate).prefix_for(@relation2[:id]) \
            .should == @relation2.prefix_for(@relation2[:id])
          
        end
      end
      
      describe 'when one of the joined relations is an alias' do
        before do
          @aliased_relation = @relation1.as(:alias)
        end
        
        it "returns the alias of the relation containing the attribute" do
          Join.new("INNER JOIN", @aliased_relation, @relation2, @predicate).prefix_for(@aliased_relation[:id]) \
            .should == @aliased_relation.alias
          Join.new("INNER JOIN", @aliased_relation, @relation2, @predicate).prefix_for(@relation2[:id]) \
            .should == @relation2.prefix_for(@relation2[:id])
        end
      end
    end
    
    describe '#engine' do
      it "delegates to a relation's engine" do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).engine.should == @relation1.engine
      end
    end
    
    describe 'with simple relations' do
      describe '#attributes' do
        it 'combines the attributes of the two relations' do
          simple_join = Join.new("INNER JOIN", @relation1, @relation2, @predicate)
          simple_join.attributes.should ==
            (@relation1.attributes + @relation2.attributes).collect { |a| a.bind(simple_join) }
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
          Join.new("INNER JOIN", @relation1.select(@relation1[:id].equals(1)),
                                 @relation2.select(@relation2[:id].equals(2)), @predicate).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`, `photos`.`id`, `photos`.`user_id`, `photos`.`camera_id`
            FROM `users`
              INNER JOIN `photos` ON `users`.`id` = `photos`.`user_id`
            WHERE `users`.`id` = 1
              AND `photos`.`id` = 2
          ")          
        end
      end
    end
    
    describe 'with aggregated relations' do
      before do
        @aggregation = @relation2 \
          .aggregate(@relation2[:user_id], @relation2[:id].count) \
          .group(@relation2[:user_id]) \
          .rename(@relation2[:id].count, :cnt) \
          .as('photo_count')
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
              SELECT `users`.`id`, `users`.`name`, `photo_count`.`user_id`, `photo_count`.`cnt`
              FROM `users`
                INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photo_count`
                  ON `users`.`id` = `photo_count`.`user_id`
            ")
          end
        end

        describe 'with the aggregation on the left' do
          it 'manufactures sql joining the right table to a derived table' do
            Join.new("INNER JOIN", @aggregation, @relation1, @predicate).to_sql.should be_like("
              SELECT `photo_count`.`user_id`, `photo_count`.`cnt`, `users`.`id`, `users`.`name`
              FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photo_count`
                INNER JOIN `users`
                  ON `users`.`id` = `photo_count`.`user_id`
            ")
          end
        end

        it "keeps selects on the aggregation within the derived table" do
          Join.new("INNER JOIN", @relation1, @aggregation.select(@aggregation[:user_id].equals(1)), @predicate).to_sql.should be_like("
            SELECT `users`.`id`, `users`.`name`, `photo_count`.`user_id`, `photo_count`.`cnt`
            FROM `users`
              INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` WHERE `photos`.`user_id` = 1 GROUP BY `photos`.`user_id`) AS `photo_count`
                ON `users`.`id` = `photo_count`.`user_id`
          ")
        end
      end
    end
  end
end