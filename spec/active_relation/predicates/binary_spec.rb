require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Predicates::Binary do
  before do
    @relation1 = ActiveRelation::Relations::Table.new(:foo)
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
    @attribute1 = ActiveRelation::Primitives::Attribute.new(@relation1, :name1)
    @attribute2 = ActiveRelation::Primitives::Attribute.new(@relation2, :name2)
    class ActiveRelation::Predicates::ConcreteBinary < ActiveRelation::Predicates::Binary
      def predicate_sql
        "<=>"
      end
    end
  end
  
  describe '==' do
    it "obtains if attribute1 and attribute2 are identical" do
      ActiveRelation::Predicates::Binary.new(@attribute1, @attribute2).should == ActiveRelation::Predicates::Binary.new(@attribute1, @attribute2)
      ActiveRelation::Predicates::Binary.new(@attribute1, @attribute2).should_not == ActiveRelation::Predicates::Binary.new(@attribute1, @attribute1)
    end
    
    it "obtains if the concrete type of the ActiveRelation::Predicates::Binarys are identical" do
      ActiveRelation::Predicates::Binary.new(@attribute1, @attribute2).should == ActiveRelation::Predicates::Binary.new(@attribute1, @attribute2)
      ActiveRelation::Predicates::Binary.new(@attribute1, @attribute2).should_not == ActiveRelation::Predicates::ConcreteBinary.new(@attribute1, @attribute2)
    end
  end
  
  describe '#qualify' do
    it "distributes over the predicates and attributes" do
      ActiveRelation::Predicates::ConcreteBinary.new(@attribute1, @attribute2).qualify. \
        should == ActiveRelation::Predicates::ConcreteBinary.new(@attribute1.qualify, @attribute2.qualify)
    end
  end
  
  describe '#to_sql' do
    it 'manufactures correct sql' do
      ActiveRelation::Predicates::ConcreteBinary.new(@attribute1, @attribute2).to_sql.should be_like("""
        `foo`.`name1` <=> `bar`.`name2`
      """)
    end
  end
end