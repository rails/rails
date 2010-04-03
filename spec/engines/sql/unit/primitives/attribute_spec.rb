require 'spec_helper'

module Arel
  describe Attribute do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe '#column' do
      it "returns the corresponding column in the relation" do
        @attribute.column.should == @relation.column_for(@attribute)
      end
    end

    describe '#to_sql' do
      describe 'for a simple attribute' do
        it "manufactures sql with an alias" do
          sql = @attribute.to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{`users`.`id`})
          end

          adapter_is :oracle do
            sql.should be_like(%Q{"USERS"."ID"})
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{"users"."id"})
          end
        end
      end
    end
  end
end
