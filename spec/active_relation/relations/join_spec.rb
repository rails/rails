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
  
    describe '#qualify' do
      it 'distributes over the relations and predicates' do
        Join.new("INNER JOIN", @relation1, @relation2, @predicate).qualify. \
          should == Join.new("INNER JOIN", @relation1.qualify, @relation2.qualify, @predicate.qualify)
      end
    end
    
    describe '#attributes' do
      describe 'with simple relations' do
        it 'combines the attributes of the two relations' do
          Join.new("INNER JOIN", @relation1, @relation2, @predicate).attributes.should ==
            @relation1.attributes + @relation2.attributes
        end
      end
      
      describe 'with aggregated relations' do
        it '' do
        end
      end
    end
  
    describe '#to_sql' do
      describe 'with simple relations' do
        before do
          @relation1 = @relation1.select(@relation1[:id].equals(1))
        end
        
        it 'manufactures sql joining the two tables on the predicate, merging the selects' do
          Join.new("INNER JOIN", @relation1, @relation2, @predicate).to_sql.should be_like("""
            SELECT `foo`.`name`, `foo`.`id`, `bar`.`name`, `bar`.`foo_id`, `bar`.`id`
            FROM `foo`
              INNER JOIN `bar` ON `foo`.`id` = `bar`.`id`
            WHERE
              `foo`.`id` = 1
          """)
        end
      end
      
      describe 'with aggregated relations' do
        before do
          @relation = Table.new(:users)
          photos = Table.new(:photos)
          @aggregate_relation = photos.project(photos[:user_id], photos[:id].count).rename(photos[:id].count, :cnt) \
                                  .group(photos[:user_id]).as(:photo_count)
          @predicate = Equality.new(@aggregate_relation[:user_id], @relation[:id])
        end
        
        it 'manufactures sql joining the left table to a derived table' do
          Join.new("INNER JOIN", @relation, @aggregate_relation, @predicate).to_sql.should be_like("""
            SELECT `users`.`name`, `users`.`id`, `photo_count`.`user_id`, `photo_count`.`cnt`
            FROM `users`
              INNER JOIN (SELECT `photos`.`user_id`, COUNT(`photos`.`id`) AS `cnt` FROM `photos` GROUP BY `photos`.`user_id`) AS `photo_count`
                ON `photo_count`.`user_id` = `users`.`id`
          """)
        end
      end
    end
  end
end