require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe BinaryPredicate do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute1 = Attribute.new(@relation1, :name1)
    @attribute2 = Attribute.new(@relation2, :name2)
    class ConcreteBinaryPredicate < BinaryPredicate
      def predicate_sql
        "<=>"
      end
    end
  end
  
  describe '==' do
    it "obtains if attribute1 and attribute2 are identical" do
      BinaryPredicate.new(@attribute1, @attribute2).should == BinaryPredicate.new(@attribute1, @attribute2)
      BinaryPredicate.new(@attribute1, @attribute2).should_not == BinaryPredicate.new(@attribute1, @attribute1)
    end
    
    it "obtains if the concrete type of the BinaryPredicates are identical" do
      ConcreteBinaryPredicate.new(@attribute1, @attribute2).should == ConcreteBinaryPredicate.new(@attribute1, @attribute2)
      BinaryPredicate.new(@attribute1, @attribute2).should_not == ConcreteBinaryPredicate.new(@attribute1, @attribute2)
    end
  end
  
  describe '#qualify' do
    it "distributes over the predicates and attributes" do
      ConcreteBinaryPredicate.new(@attribute1, @attribute2).qualify. \
        should == ConcreteBinaryPredicate.new(@attribute1.qualify, @attribute2.qualify)
    end
  end
  
  describe '#to_sql' do
    it 'manufactures correct sql' do
      ConcreteBinaryPredicate.new(@attribute1, @attribute2).to_sql.should be_like("""
        `foo`.`name1` <=> `bar`.`name2`
      """)
    end
  end
end