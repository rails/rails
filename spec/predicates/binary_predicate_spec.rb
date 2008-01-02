require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe BinaryPredicate do
  before do
    @relation1 = TableRelation.new(:foo)
    @relation2 = TableRelation.new(:bar)
    @attribute1 = Attribute.new(@relation1, :attribute_name1)
    @attribute2 = Attribute.new(@relation2, :attribute_name2)
    class ConcreteBinaryPredicate < BinaryPredicate
      def predicate_name
        :equals
      end
    end
  end
  
  describe '#initialize' do
    it "requires that both columns come from the same relation" do
      pending
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
  
  describe '#to_sql' do
    it 'manufactures correct sql' do
      ConcreteBinaryPredicate.new(@attribute1, @attribute2).to_sql.should == ConditionsBuilder.new do
        equals do
          column :foo, :attribute_name1
          column :bar, :attribute_name2
        end
      end
    end
  end
end