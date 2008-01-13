require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe ActiveRelation::Primitives::Aggregation do
  before do
    @relation1 = ActiveRelation::Relations::Table.new(:foo)
    @relation2 = ActiveRelation::Relations::Table.new(:bar)
  end
  
  describe '==' do
    it 'obtains if the attribute and function sql are identical' do
      @relation1[:id].sum.should == @relation1[:id].sum
      @relation1[:id].sum.should_not == @relation1[:name].sum
      @relation1[:id].sum.should_not == @relation1[:name].average 
      @relation1[:id].sum.should_not == @relation2[:id].sum
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
