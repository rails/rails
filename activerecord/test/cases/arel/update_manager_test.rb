# frozen_string_literal: true

require_relative "helper"
require_relative "support/tree_manager_behavior"

module Arel
  class UpdateManagerTest < Arel::Test
    include TreeManagerBehavior

    test "should not quote sql literals" do
      table = Table.new(:users)
      um = Arel::UpdateManager.new
      um.table table
      um.set [[table[:name], Arel::Nodes::BindParam.new(1)]]
      assert_like %{ UPDATE "users" SET "name" =  ? }, um.to_sql
    end

    test "handles limit properly" do
      table = Table.new(:users)
      um = Arel::UpdateManager.new
      um.key = "id"
      um.take 10
      um.table table
      um.set [[table[:name], nil]]
      assert_match(/LIMIT 10/, um.to_sql)
    end

    test "having sets having" do
      users_table = Table.new(:users)
      posts_table = Table.new(:posts)
      join_source = Arel::Nodes::InnerJoin.new(users_table, posts_table)

      update_manager = Arel::UpdateManager.new
      update_manager.table(join_source)
      update_manager.group(["posts.id"])
      update_manager.having("count(posts.id) >= 2")

      assert_equal(["count(posts.id) >= 2"], update_manager.ast.havings)
    end

    test "group adds columns to the AST when group value is a String" do
      users_table = Table.new(:users)
      posts_table = Table.new(:posts)
      join_source = Arel::Nodes::InnerJoin.new(users_table, posts_table)

      update_manager = Arel::UpdateManager.new
      update_manager.table(join_source)
      update_manager.group(["posts.id"])
      update_manager.having("count(posts.id) >= 2")

      assert_equal(1, update_manager.ast.groups.count)
      group_ast = update_manager.ast.groups.first
      assert_kind_of Nodes::Group, group_ast
      assert_equal("posts.id", group_ast.expr)
      assert_equal(["count(posts.id) >= 2"], update_manager.ast.havings)
    end

    test "group adds columns to the AST when group value is a Symbol" do
      users_table = Table.new(:users)
      posts_table = Table.new(:posts)
      join_source = Arel::Nodes::InnerJoin.new(users_table, posts_table)

      update_manager = Arel::UpdateManager.new
      update_manager.table(join_source)
      update_manager.group([:"posts.id"])
      update_manager.having("count(posts.id) >= 2")

      assert_equal(1, update_manager.ast.groups.count)
      group_ast = update_manager.ast.groups.first
      assert_kind_of Nodes::Group, group_ast
      assert_equal("posts.id", group_ast.expr)
      assert_equal(["count(posts.id) >= 2"], update_manager.ast.havings)
    end

    test "set updates with null" do
      table = Table.new(:users)
      um = Arel::UpdateManager.new
      um.table table
      um.set [[table[:name], nil]]
      assert_like %{ UPDATE "users" SET "name" =  NULL }, um.to_sql
    end

    test "set takes a string" do
      table = Table.new(:users)
      um = Arel::UpdateManager.new
      um.table table
      um.set Nodes::SqlLiteral.new "foo = bar"
      assert_like %{ UPDATE "users" SET foo = bar }, um.to_sql
    end

    test "set takes a list of lists" do
      table = Table.new(:users)
      um = Arel::UpdateManager.new
      um.table table
      um.set [[table[:id], 1], [table[:name], "hello"]]
      assert_like %{
        UPDATE "users" SET "id" = 1, "name" =  'hello'
      }, um.to_sql
    end

    test "set chains" do
      table = Table.new(:users)
      um = Arel::UpdateManager.new
      assert_equal um, um.set([[table[:id], 1], [table[:name], "hello"]])
    end

    test "table generates an update statement" do
      um = Arel::UpdateManager.new
      um.table Table.new(:users)
      assert_like %{ UPDATE "users" }, um.to_sql
    end

    test "table chains" do
      um = Arel::UpdateManager.new
      assert_equal um, um.table(Table.new(:users))
    end

    test "table generates an update statement with joins" do
      um = Arel::UpdateManager.new

      table = Table.new(:users)
      join_source = Arel::Nodes::JoinSource.new(
        table,
        [table.create_join(Table.new(:posts))]
      )

      um.table join_source
      assert_like %{ UPDATE "users" INNER JOIN "posts" }, um.to_sql
    end

    test "where generates a where clause" do
      table = Table.new :users
      um = Arel::UpdateManager.new
      um.table table
      um.where table[:id].eq(1)
      assert_like %{
        UPDATE "users" WHERE "users"."id" = 1
      }, um.to_sql
    end

    test "where chains" do
      table = Table.new :users
      um = Arel::UpdateManager.new
      um.table table
      assert_equal um, um.where(table[:id].eq(1))
    end

    test "key can be set" do
      table = Table.new :users
      um = Arel::UpdateManager.new
      um.key = table[:foo]
      assert_equal table[:foo], um.ast.key
    end

    test "key can be accessed" do
      table = Table.new :users
      um = Arel::UpdateManager.new
      um.key = table[:foo]
      assert_equal table[:foo], um.key
    end

    test "#returning accepts a returning clause" do
      users   = Table.new :users
      manager = Arel::UpdateManager.new
      manager.table users
      manager.returning Arel.star

      assert_like %{
          UPDATE "users" RETURNING *
        }, manager.to_sql
    end

    test "#returning accepts multiple values as returning clause" do
      users   = Table.new :users
      manager = Arel::UpdateManager.new
      manager.table users
      manager.returning Arel.star
      manager.returning [users[:id], users[:name]]

      assert_like %{
          UPDATE "users" RETURNING *, "users"."id", "users"."name"
        }, manager.to_sql
    end

    test "#returning chains" do
      manager = Arel::UpdateManager.new
      assert_equal manager, manager.returning(Arel.star)
    end

    private
      def build_manager(table = nil)
        Arel::UpdateManager.new(table)
      end
  end
end
