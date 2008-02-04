require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Join do
    before do
      @relation1 = Table.new(:foo)
      @relation2 = Table.new(:bar)
      @predicate = Equality.new(@relation1[:id], @relation2[:id])
    end

    describe '==' do
      it 'obtains if the two relations and the predicate are identical' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).should == Join.new("INNER JOIN", @relation1, @relation2, @predicate)
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).should_not == Join.new("INNER JOIN", @relation1, @relation1, @predicate)
      end
  
      it 'is commutative on the relations' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).should == Join.new("INNER JOIN", @relation2, @relation1, @predicate)
      end
    end
    
    describe '[]' do
      it "" do
        pending
      end
    end

    describe '#qualify' do
      it 'distributes over the relations and predicates' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).qualify. \
          should == Join.new("INNER JOIN", @relation1.qualify, @relation2.qualify, @predicate.qualify)
      end
    end

    describe '#attributes' do
      describe 'with simple relations' do
        before do
          @join = Join.new("INNER JOIN", @relation1, @relation2, @predicate)
        end
        
        it 'combines the attributes of the two relations' do
          @join.attributes.should ==
            (@relation1.attributes + @relation2.attributes).collect { |a| a.substitute(@join) }
        end
      end

      describe 'with aggregated relations' do
        it '' do
          pending
        end
      end
    end

    describe '#to_sql' do
      describe 'with simple relations' do
        it 'manufactures sql joining the two tables on the predicate' do
          Join.new("INNER JOIN", @relation1, @relation2, @predicate).to_sql.should be_like("""
            SELECT `foo`.`name`, `foo`.`id`, `bar`.`name`, `bar`.`foo_id`, `bar`.`id`
            FROM `foo`
              INNER JOIN `bar` ON `foo`.`id` = `bar`.`id`
          """)
        end

        it 'manufactures sql joining the two tables, merging any selects' do
          Join.new("INNER JOIN", @relation1.select(@relation1[:id].equals(1)),
                                 @relation2.select(@relation2[:id].equals(2)), @predicate).to_sql.should be_like("""
            SELECT `foo`.`name`, `foo`.`id`, `bar`.`name`, `bar`.`foo_id`, `bar`.`id`
            FROM `foo`
              INNER JOIN `bar` ON `foo`.`id` = `bar`.`id`
            WHERE `foo`.`id` = 1
              AND `bar`.`id` = 2
          """)          
        end
      end

      describe 'aggregated relations' do
        before do
          @relation = Table.new(:users)
          photos = Table.new(:photos)
          aggregate_relation = photos.aggregate(photos[:user_id], photos[:id].count).group(photos[:user_id])
          @aggregate_relation = aggregate_relation.rename(photos[:id].count, :cnt).as(:photo_count)
          @predicate = Equality.new(@aggregate_relation[:user_id], @relation[:id])
        end

        describe 'with the expression on the right' do
          it 'manufactures sql joining the left table to a derived table' do
            Join.new("INNER JOIN", @relation, @aggregate_relation, @predicate).to_sql.should be_like("""
              SELECT `users`.`name`, `users`.`id`, `photo_count`.`user_id`, `photo_count`.`cnt`
              FROM `users`
                INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photo_count`
                  ON `photo_count`.`user_id` = `users`.`id`
            """)
          end
        end

        describe 'with the expression on the left' do
          it 'manufactures sql joining the right table to a derived table' do
            Join.new("INNER JOIN", @aggregate_relation, @relation, @predicate).to_sql.should be_like("""
              SELECT `photo_count`.`user_id`, `photo_count`.`cnt`, `users`.`name`, `users`.`id`
              FROM (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photo_count`
                INNER JOIN `users`
                  ON `photo_count`.`user_id` = `users`.`id`
            """)
          end
        end

        it "keeps selects on the expression within the derived table" do
          pending
          Join.new("INNER JOIN", @relation, @aggregate_relation.select(@aggregate_relation[:user_id].equals(1)), @predicate).to_sql.should be_like("""
            SELECT `users`.`name`, `users`.`id`, `photo_count`.`user_id`, `photo_count`.`cnt`
            FROM `users`
              INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` WHERE `photos`.`user_id` = 1 GROUP BY `photos`.`user_id`) AS `photo_count`
                ON `photo_count`.`user_id` = `users`.`id`
          """)
        end
      end
    end
  end
end