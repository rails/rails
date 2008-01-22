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
    
    describe Aggregation::Transformations do
      describe '#substitute' do
        it "distributes over the attribute and alias" do
          Aggregation.new(@relation1[:id], "SUM", "alias").substitute(@relation2). \
            should == Aggregation.new(@relation1[:id].substitute(@relation2), "SUM", "alias")
        end
      end
    
      describe '#as' do
        it "manufactures an aliased aggregation" do
          Aggregation.new(@relation1[:id], "SUM").as(:doof). \
            should == Aggregation.new(@relation1[:id], "SUM", :doof)
        end
      end
      
      describe '#to_attribute' do
        it "manufactures an attribute the name of which corresponds to the aggregation's alias" do
          Aggregation.new(@relation1[:id], "SUM", :schmaggregation).to_attribute. \
            should == Attribute.new(@relation1, :schmaggregation)
        end
      end
    end
    
    describe '#relation' do
      it "delegates to the attribute" do
        Aggregation.new(@relation1[:id], "SUM").relation.should == @relation1
      end
    end
  
    describe '#to_sql' do
      it 'manufactures sql with an aggregation function' do
        Aggregation.new(@relation1[:id], "MAX").to_sql.should be_like("""
          MAX(`foo`.`id`)
        """)
      end
      
      it 'manufactures sql with an aliased aggregation function' do
        Aggregation.new(@relation1[:id], "MAX", "marx").to_sql.should be_like("""
          MAX(`foo`.`id`) AS `marx`
        """)
      end
    end
  end
end