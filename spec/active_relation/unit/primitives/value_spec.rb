require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module ActiveRelation
  describe Value do
    before do
      @relation = Table.new(:users)
    end
    
    describe '#to_sql' do
      it "appropriately quotes the value" do
        Value.new(1, @relation).to_sql.should be_like('1')
        Value.new('asdf', @relation).to_sql.should be_like("'asdf'")
      end
    end

    describe '#format' do
      it "returns the sql of the provided object" do
        Value.new(1, @relation).format(@relation[:id]).should == @relation[:id].to_sql
      end
    end

    describe '#bind' do
      it "manufactures a new value whose relation is the provided relation" do
        Value.new(1, @relation).bind(another_relation = Table.new(:photos)).should == Value.new(1, another_relation)
      end
    end
  end
end