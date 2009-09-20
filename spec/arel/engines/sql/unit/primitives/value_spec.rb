require 'spec_helper'

module Arel
  describe Value do
    before do
      @relation = Table.new(:users)
    end

    describe '#to_sql' do
      it "appropriately quotes the value" do
        Value.new(1, @relation).to_sql.should be_like('1')

        adapter_is_not :postgresql do
          Value.new('asdf', @relation).to_sql.should be_like("'asdf'")
        end

        adapter_is :postgresql do
          Value.new('asdf', @relation).to_sql.should be_like("E'asdf'")
        end
      end
    end

    describe '#format' do
      it "returns the sql of the provided object" do
        Value.new(1, @relation).format(@relation[:id]).should == @relation[:id].to_sql
      end
    end
  end
end
