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

      describe 'for an inexistent attribute' do
        it "manufactures sql" do
          sql = @relation[:does_not_exist].to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{`users`.`does_not_exist`})
          end

          adapter_is :oracle do
            sql.should be_like(%Q{"USERS"."DOEST_NOT_EXIST"})
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{"users"."does_not_exist"})
          end
        end
      end

    end
  end
end
