require 'spec_helper'

module Arel
  describe Lock do
    before do
      @relation = Table.new(:users)
    end

    describe '#to_sql' do
      it "manufactures a simple select query lock" do
        sql = @relation.lock.to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            SELECT `users`.`id`, `users`.`name`
            FROM `users` FOR UPDATE
          })
        end

        adapter_is :postgresql do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM "users" FOR UPDATE
          })
        end

        adapter_is :sqlite3 do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM "users"
          })
        end
      end

      it "manufactures a select query locking with a given lock" do
        sql = @relation.lock("LOCK IN SHARE MODE").to_sql

        adapter_is :mysql do
          sql.should be_like(%Q{
            SELECT `users`.`id`, `users`.`name`
            FROM `users` LOCK IN SHARE MODE
          })
        end

        adapter_is :postgresql do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM "users" LOCK IN SHARE MODE
          })
        end

        adapter_is :sqlite3 do
          sql.should be_like(%Q{
            SELECT "users"."id", "users"."name"
            FROM "users"
          })
        end
      end
    end
  end
end
