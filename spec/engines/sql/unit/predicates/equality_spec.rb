require 'spec_helper'

module Arel
  module Predicates
    describe Equality do
      before do
        @relation1 = Arel::Table.new(:users)
        @relation2 = Arel::Table.new(:photos)
        @attribute1 = @relation1[:id]
        @attribute2 = @relation2[:user_id]
      end

      describe '#to_sql' do
        describe 'when relating to a non-nil value' do
          it "manufactures an equality predicate" do
            sql = Equality.new(@attribute1, @attribute2).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{`users`.`id` = `photos`.`user_id`})
            end

            adapter_is :oracle do
              sql.should be_like(%Q{"USERS"."ID" = "PHOTOS"."USER_ID"})
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{"users"."id" = "photos"."user_id"})
            end
          end
        end

        describe 'when relation to a nil value' do
          before do
            @nil = nil
          end

          it "manufactures an is null predicate" do
            sql = Equality.new(@attribute1, @nil).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{`users`.`id` IS NULL})
            end

            adapter_is :oracle do
              sql.should be_like(%Q{"USERS"."ID" IS NULL})
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{"users"."id" IS NULL})
            end
          end
        end

        describe "when relating to a nil Value" do
          it "manufactures an IS NULL predicate" do
            value = nil.bind(@relation1)
            sql = Equality.new(@attribute1, value).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{`users`.`id` IS NULL})
            end

            adapter_is :oracle do
              sql.should be_like(%Q{"USERS"."ID" IS NULL})
            end

            adapter_is_not :mysql, :oracle do
              sql.should be_like(%Q{"users"."id" IS NULL})
            end
          end
        end
      end
    end
  end
end
