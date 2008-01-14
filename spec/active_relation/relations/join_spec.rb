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
  
    describe '#to_sql' do
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
  end
end