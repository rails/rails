# frozen_string_literal: true

require_relative "helper"

module Arel
  class DeleteManagerTest < Arel::Spec
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

    describe "returning" do
      it "accepts a returning clause" do
        users   = Table.new :users
        manager = Arel::DeleteManager.new
        manager.from users
        manager.returning Arel.star

        _(manager.to_sql).must_be_like %{
          DELETE FROM "users" RETURNING *
        }
      end

      it "accepts multiple values as returning clause" do
        users   = Table.new :users
        manager = Arel::DeleteManager.new
        manager.from users
        manager.returning Arel.star
        manager.returning [users[:id], users[:name]]

        _(manager.to_sql).must_be_like %{
          DELETE FROM "users" RETURNING *, "users"."id", "users"."name"
        }
      end

      it "chains" do
        manager = Arel::UpdateManager.new
        _(manager.returning(Arel.star)).must_equal manager
      end
    end
  end
end
