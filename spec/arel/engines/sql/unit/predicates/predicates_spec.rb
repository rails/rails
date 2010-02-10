require 'spec_helper'

module Arel
  module Predicates
    describe Predicate do
      before do
        @relation = Arel::Table.new(:users)
        @attribute1 = @relation[:id]
        @attribute2 = @relation[:name]
        @operand1 = Arel::Predicates::Equality.new(@attribute1, 1)
        @operand2 = Arel::Predicates::Equality.new(@attribute2, "name")
      end

      describe "when being combined with another predicate with AND logic" do
        describe "#to_sql" do
          it "manufactures sql with an AND operation" do
            sql = @operand1.and(@operand2).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                (`users`.`id` = 1 AND `users`.`name` = 'name')
              })
            end

            adapter_is :sqlite3 do
              sql.should be_like(%Q{
                ("users"."id" = 1 AND "users"."name" = 'name')
              })
            end

            adapter_is :postgresql do
              sql.should be_like(%Q{
                ("users"."id" = 1 AND "users"."name" = E'name')
              })
            end

            adapter_is :oracle do
              sql.should be_like(%Q{
                ("USERS"."ID" = 1 AND "USERS"."NAME" = 'name')
              })
            end
          end
        end
      end

      describe "when being combined with another predicate with OR logic" do
        describe "#to_sql" do
          it "manufactures sql with an OR operation" do
            sql = @operand1.or(@operand2).to_sql

            adapter_is :mysql do
              sql.should be_like(%Q{
                (`users`.`id` = 1 OR `users`.`name` = 'name')
              })
            end

            adapter_is :sqlite3 do
              sql.should be_like(%Q{
                ("users"."id" = 1 OR "users"."name" = 'name')
              })
            end

            adapter_is :postgresql do
              sql.should be_like(%Q{
                ("users"."id" = 1 OR "users"."name" = E'name')
              })
            end

            adapter_is :oracle do
              sql.should be_like(%Q{
                ("USERS"."ID" = 1 OR "USERS"."NAME" = 'name')
              })
            end
          end
        end
      end
    end
  end
end
