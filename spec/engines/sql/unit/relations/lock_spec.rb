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

        adapter_is :oracle do
          sql.should be_like(%Q{
            SELECT "USERS"."ID", "USERS"."NAME"
            FROM "USERS" FOR UPDATE
          })

          sql_with_order_by = @relation.order(@relation[:id]).take(1).lock.to_sql
          sql_with_order_by.should be_like(%Q{
            SELECT "USERS"."ID", "USERS"."NAME"
            FROM "USERS"
            WHERE "ID" IN (select * from
                          (SELECT "ID" FROM "USERS" ORDER BY "USERS"."ID" ASC)
                          where rownum <= 1)
            FOR UPDATE
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

        adapter_is :oracle do
          sql.should be_like(%Q{
            SELECT "USERS"."ID", "USERS"."NAME"
            FROM "USERS" LOCK IN SHARE MODE
          })
        end
      end
    end
  end
end
