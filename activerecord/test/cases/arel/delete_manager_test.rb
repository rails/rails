# frozen_string_literal: true

require_relative "helper"
require_relative "support/tree_manager_behavior"


module Arel
  class DeleteManagerTest < Arel::Test
    include TreeManagerBehavior

    test "handles limit properly" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      dm.take 10
      dm.from table
      dm.key = table[:id]
      assert_match(/LIMIT 10/, dm.to_sql)
    end

    test "from uses from" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      dm.from table
      assert_like %{ DELETE FROM "users" }, dm.to_sql
    end

    test "from chains" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      assert_equal dm, dm.from(table)
    end

    test "where uses where values" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      dm.from table
      dm.where table[:id].eq(10)
      assert_like %{ DELETE FROM "users" WHERE "users"."id" = 10}, dm.to_sql
    end

    test "where chains" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      assert_equal dm, dm.where(table[:id].eq(10))
    end

    test "#returning accepts a returning clause" do
      users   = Table.new :users
      manager = Arel::DeleteManager.new
      manager.from users
      manager.returning Arel.star

      assert_like %{
        DELETE FROM "users" RETURNING *
      }, manager.to_sql
    end

    test "#returning accepts multiple values as returning clause" do
      users   = Table.new :users
      manager = Arel::DeleteManager.new
      manager.from users
      manager.returning Arel.star
      manager.returning [users[:id], users[:name]]

      assert_like %{
        DELETE FROM "users" RETURNING *, "users"."id", "users"."name"
      }, manager.to_sql
    end

    test "#returning chains" do
      manager = Arel::UpdateManager.new

      assert_equal manager, manager.returning(Arel.star)
    end

    private
      def build_manager(table = nil)
        Arel::DeleteManager.new(table)
      end
  end
end
