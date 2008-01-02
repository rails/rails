require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe 'between two relations' do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @predicate = EqualityPredicate.new(@relation1[:a], @relation2[:b])
  end
  
  describe '==' do
    it 'obtains if the two relations and the predicate are identical' do
      JoinRelation.new(@relation1, @relation2, @predicate).should == JoinRelation.new(@relation1, @relation2, @predicate)
      JoinRelation.new(@relation1, @relation2, @predicate).should_not == JoinRelation.new(@relation1, @relation1, @predicate)
    end
  
    it 'is commutative on the relations' do
      JoinRelation.new(@relation1, @relation2, @predicate).should == JoinRelation.new(@relation2, @relation1, @predicate)
    end
  end
  
  describe '#to_sql' do
    before do
      @relation1 = @relation1.select(@relation1[:c] == @relation2[:d])
      class ConcreteJoinRelation < JoinRelation
        def join_name
          :inner_join
        end
      end
    end
    
    it 'manufactures sql joining the two tables on the predicate, merging the selects' do
      ConcreteJoinRelation.new(@relation1, @relation2, @predicate).to_sql.to_s.should == SelectBuilder.new do
        select { all }
        from :foo do
          inner_join :bar do
            equals do
              column :foo, :a
              column :bar, :b
            end
          end
        end
        where do
          equals do
            column :foo, :c
            column :bar, :d
          end
        end
      end.to_s
    end
  end
end