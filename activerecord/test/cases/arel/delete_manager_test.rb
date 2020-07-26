# frozen_string_literal: true

require_relative "helper"

module Arel
  class DeleteManagerTest < Arel::Spec
    describe "new" do
      it "takes an engine" do
        Arel::DeleteManager.new
      end
    end

    it "handles limit properly" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      dm.take 10
      dm.from table
      dm.key = table[:id]
      assert_match(/LIMIT 10/, dm.to_sql)
    end

    describe "from" do
      it "uses from" do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new
        dm.from table
        _(dm.to_sql).must_be_like %{ DELETE FROM "users" }
      end

      it "chains" do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new
        _(dm.from(table)).must_equal dm
      end
    end

    describe "where" do
      it "uses where values" do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new
        dm.from table
        dm.where table[:id].eq(10)
        _(dm.to_sql).must_be_like %{ DELETE FROM "users" WHERE "users"."id" = 10}
      end

      it "chains" do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new
        _(dm.where(table[:id].eq(10))).must_equal dm
      end
    end

    describe "lock" do
      it "adds a subquery with lock node" do
        table = Table.new :users
        dm = Arel::DeleteManager.new
        dm.from table
        dm.key = table[:id]

        _(dm.lock.to_sql).must_be_like %{
          DELETE FROM "users" WHERE "users"."id" IN
          (SELECT "users"."id" FROM "users" FOR UPDATE)
        }
      end

      describe "with mysql2 adapter" do
        it "uses subsubquery with temporary table" do
          table = Table.new :users
          dm = Arel::DeleteManager.new
          dm.from table
          dm.key = table[:id]
          connection = FakeRecord::Connection.new.tap { |conn| conn.adapter_name = "Mysql2" }

          _(dm.lock(Arel.sql("FOR UPDATE"), connection).to_sql).must_be_like %{
            DELETE FROM "users" WHERE "users"."id" IN
              (SELECT "id" FROM
                (SELECT "users"."id" FROM "users" FOR UPDATE) AS __active_record_temp)
          }
        end
      end
    end
  end
end
