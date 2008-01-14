require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Projection do
    before do
      @relation1 = Table.new(:foo)
      @relation2 = Table.new(:bar)
      @attribute1 = @relation1[:id]
      @attribute2 = @relation2[:id]
    end
  
    describe '==' do
      it "obtains if the relations and attributes are identical" do
        Projection.new(@relation1, @attribute1, @attribute2).should == Projection.new(@relation1, @attribute1, @attribute2)
        Projection.new(@relation1, @attribute1).should_not == Projection.new(@relation2, @attribute1)
        Projection.new(@relation1, @attribute1).should_not == Projection.new(@relation1, @attribute2)
      end
    end
  
    describe '#qualify' do
      it "distributes over the relation and attributes" do
        Projection.new(@relation1, @attribute1).qualify. \
          should == Projection.new(@relation1.qualify, @attribute1.qualify)
      end
    end
  
    describe '#to_sql' do
      it "manufactures sql with a limited select clause" do
        Projection.new(@relation1, @attribute1).to_sql.should be_like("""
          SELECT `foo`.`id`
          FROM `foo`
        """)
      end
    end
  end
end