require 'spec_helper'

module Arel
  describe Where do
    before do
      @relation = Table.new(:users)
      @predicate = @relation[:id].eq(1)
    end

    describe '#to_sql' do
      describe 'when given a predicate' do
        it "manufactures sql with where clause conditions" do
          sql = Where.new(@relation, @predicate).to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`
              FROM `users`
              WHERE `users`.`id` = 1
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT "USERS"."ID", "USERS"."NAME"
              FROM "USERS"
              WHERE "USERS"."ID" = 1
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name"
              FROM "users"
              WHERE "users"."id" = 1
            })
          end
        end
      end

      describe 'when given a string' do
        it "passes the string through to the where clause" do
          sql = Where.new(@relation, 'asdf').to_sql

          adapter_is :mysql do
            sql.should be_like(%Q{
              SELECT `users`.`id`, `users`.`name`
              FROM `users`
              WHERE asdf
            })
          end

          adapter_is :oracle do
            sql.should be_like(%Q{
              SELECT "USERS"."ID", "USERS"."NAME"
              FROM "USERS"
              WHERE asdf
            })
          end

          adapter_is_not :mysql, :oracle do
            sql.should be_like(%Q{
              SELECT "users"."id", "users"."name"
              FROM "users"
              WHERE asdf
            })
          end
        end
      end
    end
  end
end
