require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Binary do
    before do
      @relation1 = Table.new(:foo)
      @relation2 = Table.new(:bar)
      @attribute1 = Attribute.new(@relation1, :name1)
      @attribute2 = Attribute.new(@relation2, :name2)
      class ConcreteBinary < Binary
        def predicate_sql
          "<=>"
        end
      end
    end
  
    describe '==' do
      it "obtains if attribute1 and attribute2 are identical" do
        Binary.new(@attribute1, @attribute2).should == Binary.new(@attribute1, @attribute2)
        Binary.new(@attribute1, @attribute2).should_not == Binary.new(@attribute1, @attribute1)
      end
    
      it "obtains if the concrete type of the Predicates::Binarys are identical" do
        Binary.new(@attribute1, @attribute2).should == Binary.new(@attribute1, @attribute2)
        Binary.new(@attribute1, @attribute2).should_not == ConcreteBinary.new(@attribute1, @attribute2)
      end
    end
  
    describe '#qualify' do
      it "distributes over the predicates and attributes" do
        ConcreteBinary.new(@attribute1, @attribute2).qualify. \
          should == ConcreteBinary.new(@attribute1.qualify, @attribute2.qualify)
      end
    end
    
    describe '#substitute' do
      it "distributes over the predicates and attributes" do
        ConcreteBinary.new(@attribute1, @attribute2).substitute(@relation2). \
          should == ConcreteBinary.new(@attribute1.substitute(@relation2), @attribute2.substitute(@relation2))
      end
    end
  
    describe '#to_sql' do
      it 'manufactures correct sql' do
        ConcreteBinary.new(@attribute1, @attribute2).to_sql.should be_like("""
          `foo`.`name1` <=> `bar`.`name2`
        """)
      end
    end
  end
end