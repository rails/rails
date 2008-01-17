require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

module ActiveRelation
  describe Aggregation do
    before do
      @relation1 = Table.new(:foo)
      @relation2 = Table.new(:bar)
    end
  
    describe '==' do
      it 'obtains if the attribute and function sql are identical' do
        Aggregation.new(@relation1[:id], "SUM").should == Aggregation.new(@relation1[:id], "SUM")
        Aggregation.new(@relation1[:id], "SUM").should_not == Aggregation.new(@relation1[:name], "SUM")
        Aggregation.new(@relation1[:id], "SUM").should_not == Aggregation.new(@relation1[:name], "SUM")
        Aggregation.new(@relation1[:id], "SUM").should_not == Aggregation.new(@relation2[:id], "SUM")
      end
    end
    
    describe '#substitute' do
      it "distributes over the attribute" do
        Aggregation.new(@relation1[:id], "SUM").substitute(@relation2). \
          should == Aggregation.new(@relation1[:id].substitute(@relation2), "SUM")
      end
    end
  
    describe '#to_sql' do
      it 'manufactures sql with an aggregation function' do
        @relation1[:id].maximum.to_sql.should be_like("""
          MAX(`foo`.`id`)
        """)
      end
    end
  end
end