require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe SelectionRelation do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @predicate1 = EqualityPredicate.new(@relation1[:id], @relation2[:foo_id])
    @predicate2 = LessThanPredicate.new(@relation1[:age], 2)
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
      SelectionRelation.new(@relation1, @predicate1).to_sql.should be_like("""
        SELECT `foo`.`name`, `foo`.`id`
        FROM `foo`
        WHERE `foo`.`id` = `bar`.`foo_id`
      """)
    end
    
    it "allows arbitrary sql" do
      SelectionRelation.new(@relation1, "asdf").to_sql.should be_like("""
        SELECT `foo`.`name`, `foo`.`id`
        FROM `foo`
        WHERE asdf
      """)
    end
  end
end