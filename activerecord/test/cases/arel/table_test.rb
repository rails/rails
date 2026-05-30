# frozen_string_literal: true

require_relative "helper"

module Arel
  class TableTest < Arel::Test
    setup do
      @relation = Table.new(:users)
    end

    test "should create join nodes" do
      join = @relation.create_join "foo", "bar"
      assert_kind_of Arel::Nodes::InnerJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    test "should create join nodes with a klass" do
      join = @relation.create_join "foo", "bar", Arel::Nodes::FullOuterJoin
      assert_kind_of Arel::Nodes::FullOuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    test "should create join nodes with a klass (2)" do
      join = @relation.create_join "foo", "bar", Arel::Nodes::OuterJoin
      assert_kind_of Arel::Nodes::OuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    test "should create join nodes with a klass (3)" do
      join = @relation.create_join "foo", "bar", Arel::Nodes::RightOuterJoin
      assert_kind_of Arel::Nodes::RightOuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    test "skip should add an offset" do
      sm = @relation.skip 2
      assert_like "SELECT FROM \"users\" OFFSET 2", sm.to_sql
    end

    test "having adds a having clause" do
      mgr = @relation.having @relation[:id].eq(10)
      assert_like %{
        SELECT FROM "users" HAVING "users"."id" = 10
      }, mgr.to_sql
    end

    test "backwards compat join noops on nil" do
      mgr = @relation.join nil

      assert_like %{ SELECT FROM "users" }, mgr.to_sql
    end

    test "backwards compat join raises EmptyJoinError on empty" do
      assert_raises(EmptyJoinError) do
        @relation.join ""
      end
    end

    test "backwards compat join takes a second argument for join type" do
      right     = @relation.alias
      predicate = @relation[:id].eq(right[:id])
      mgr = @relation.join(right, Nodes::OuterJoin).on(predicate)

      assert_like %{
        SELECT FROM "users"
          LEFT OUTER JOIN "users" "users_2"
            ON "users"."id" = "users_2"."id"
      }, mgr.to_sql
    end

    test "backwards compat join creates an outer join" do
      right     = @relation.alias
      predicate = @relation[:id].eq(right[:id])
      mgr = @relation.outer_join(right).on(predicate)

      assert_like %{
        SELECT FROM "users"
          LEFT OUTER JOIN "users" "users_2"
            ON "users"."id" = "users_2"."id"
      }, mgr.to_sql
    end

    test "group should create a group" do
      manager = @relation.group @relation[:id]
      assert_like %{
        SELECT FROM "users" GROUP BY "users"."id"
      }, manager.to_sql
    end

    test "alias should create a node that proxies to a table" do
      node = @relation.alias
      assert_equal "users_2", node.name
      assert_equal node, node[:id].relation
    end

    test "new should accept a hash" do
      rel = Table.new :users, as: "foo"
      assert_equal "foo", rel.table_alias
    end

    test "new ignores as if it equals name" do
      rel = Table.new :users, as: "users"
      assert_nil rel.table_alias
    end

    test "new should accept literal SQL" do
      rel = Table.new Arel.sql("generate_series(4, 2)")
      assert_equal Arel.sql("generate_series(4, 2)"), rel.name
    end

    test "new should accept Arel nodes" do
      node = Arel::Nodes::NamedFunction.new("generate_series", [4, 2])
      rel = Table.new node
      assert_equal node, rel.name
    end

    test "order should take an order" do
      manager = @relation.order "foo"
      assert_like %{ SELECT FROM "users" ORDER BY foo }, manager.to_sql
    end

    test "take should add a limit" do
      manager = @relation.take 1
      manager.project Nodes::SqlLiteral.new "*"
      assert_like %{ SELECT * FROM "users" LIMIT 1 }, manager.to_sql
    end

    test "project can project" do
      manager = @relation.project Nodes::SqlLiteral.new "*"
      assert_like %{ SELECT * FROM "users" }, manager.to_sql
    end

    test "project takes multiple parameters" do
      manager = @relation.project Nodes::SqlLiteral.new("*"), Nodes::SqlLiteral.new("*")
      assert_like %{ SELECT *, * FROM "users" }, manager.to_sql
    end

    test "where returns a tree manager" do
      manager = @relation.where @relation[:id].eq 1
      manager.project @relation[:id]
      assert_kind_of TreeManager, manager
      assert_like %{
        SELECT "users"."id"
        FROM "users"
        WHERE "users"."id" = 1
      }, manager.to_sql
    end

    test "should have a name" do
      assert_equal "users", @relation.name
    end

    test "[] when given a Symbol manufactures an attribute if the symbol names an attribute within the relation" do
      column = @relation[:id]
      assert_equal "id", column.name
    end

    test "equality is equal with equal ivars" do
      relation1 = Table.new(:users, as: "zomg")
      relation2 = Table.new(:users, as: "zomg")
      array = [relation1, relation2]
      assert_equal 1, array.uniq.size
    end

    test "equality is not equal with different ivars" do
      relation1 = Table.new(:users, as: "zomg")
      relation2 = Table.new(:users, as: "zomg2")
      array = [relation1, relation2]
      assert_equal 2, array.uniq.size
    end
  end
end
