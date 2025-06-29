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



    describe "with" do
      it "should support basic WITH" do
        users           = Table.new(:users)
        comments        = Table.new(:comments)
        comments_count  = Table.new(:comments_count)
        count_manager   = comments.project(comments[:user_id], Arel.star.count).group(comments[:user_id])
        spammer_manager = comments_count.project(comments_count[:user_id]).where(comments_count[:count].gt(1000))

        manager = Arel::DeleteManager.new
        manager.from users
        manager.with Arel::Nodes::TableAlias.new(count_manager, Arel.sql(comments_count.name.to_s))
        manager.where users[:id].in(spammer_manager.ast)

        _(manager.to_sql).must_be_like %{
          WITH comments_count AS (SELECT "comments"."user_id", COUNT(*) FROM "comments" GROUP BY "comments"."user_id") DELETE FROM "users" WHERE "users"."id" IN (SELECT "comments_count"."user_id" FROM "comments_count" WHERE "comments_count"."count" > 1000)
        }
      end
    end
  end
end
