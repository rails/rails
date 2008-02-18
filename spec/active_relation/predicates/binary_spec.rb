require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Binary do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @attribute1 = @relation1[:id]
      @attribute2 = @relation2[:id]
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
      it "descends" do
        ConcreteBinary.new(@attribute1, @attribute2).qualify \
          .should == ConcreteBinary.new(@attribute1, @attribute2).descend(&:qualify)
      end
    end
    
    describe '#descend' do
      it "distributes over the predicates and attributes" do
        ConcreteBinary.new(@attribute1, @attribute2).descend(&:qualify). \
          should == ConcreteBinary.new(@attribute1.qualify, @attribute2.qualify)
      end
    end
    
    describe '#bind' do
      it "distributes over the predicates and attributes" do
        ConcreteBinary.new(@attribute1, @attribute2).bind(@relation2). \
          should == ConcreteBinary.new(@attribute1.bind(@relation2), @attribute2.bind(@relation2))
      end
    end
  
    describe '#to_sql' do
      it 'manufactures sql with a binary operation' do
        ConcreteBinary.new(@attribute1, @attribute2).to_sql.should be_like("""
          `users`.`id` <=> `photos`.`id`
        """)
      end
    end
  end
end