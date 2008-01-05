require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe JoinRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @predicate = EqualityPredicate.new(@relation1[:id], @relation2[:id])
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
  
  describe '#qualify' do
    it 'distributes over the relations and predicates' do
      JoinRelation.new(@relation1, @relation2, @predicate).qualify. \
        should == JoinRelation.new(@relation1.qualify, @relation2.qualify, @predicate.qualify)
    end
  end
  
  describe '#to_sql' do
    before do
      @relation1 = @relation1.select(@relation1[:id] == @relation2[:foo_id])
      class ConcreteJoinRelation < JoinRelation
        def join_type
          :inner_join
        end
      end
    end
    
    it 'manufactures sql joining the two tables on the predicate, merging the selects' do
      ConcreteJoinRelation.new(@relation1, @relation2, @predicate).to_sql.to_s.should == SelectBuilder.new do
        select do
          column :foo, :name
          column :foo, :id
          column :bar, :name
          column :bar, :foo_id
          column :bar, :id
        end
        from :foo do
          inner_join :bar do
            equals do
              column :foo, :id
              column :bar, :id
            end
          end
        end
        where do
          equals do
            column :foo, :id
            column :bar, :foo_id
          end
        end
      end.to_s
    end
  end
end