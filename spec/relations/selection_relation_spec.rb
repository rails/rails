require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe SelectionRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @predicate1 = EqualityPredicate.new(@relation1[:id], @relation2[:foo_id])
    @predicate2 = LessThanPredicate.new(@relation1[:age], 2)
  end
  
  describe '==' do    
    it "obtains if both the predicate and the relation are identical" do
      SelectionRelation.new(@relation1, @predicate1). \
        should == SelectionRelation.new(@relation1, @predicate1)
      SelectionRelation.new(@relation1, @predicate1). \
        should_not == SelectionRelation.new(@relation2, @predicate1)
      SelectionRelation.new(@relation1, @predicate1). \
        should_not == SelectionRelation.new(@relation1, @predicate2)
    end
  end
  
  describe '#initialize' do
    it "manufactures nested selection relations if multiple predicates are provided" do
      SelectionRelation.new(@relation1, @predicate1, @predicate2). \
        should == SelectionRelation.new(SelectionRelation.new(@relation1, @predicate2), @predicate1)
    end
  end
  
  describe '#qualify' do
    it "distributes over the relation and predicates" do
      SelectionRelation.new(@relation1, @predicate1).qualify. \
        should == SelectionRelation.new(@relation1.qualify, @predicate1.qualify)
    end
  end
  
  describe '#to_sql' do
    it "manufactures sql with where clause conditions" do
      SelectionRelation.new(@relation1, @predicate1).to_sql.to_s.should == SelectBuilder.new do
        select do
          column :foo, :name
          column :foo, :id
        end
        from :foo
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