# frozen_string_literal: true

require_relative "helper"

module Arel
  class UpdateManagerTest < Arel::Spec
    it "should not quote sql literals" do
      table = Table.new(:users)
      um = Arel::UpdateManager.new
      um.table table
      um.set [[table[:name], Arel::Nodes::BindParam.new(1)]]
      _(um.to_sql).must_be_like %{ UPDATE "users" SET "name" =  ? }
    end

    it "handles limit properly" do
      table = Table.new(:users)
      um = Arel::UpdateManager.new
      um.key = "id"
      um.take 10
      um.table table
      um.set [[table[:name], nil]]
      assert_match(/LIMIT 10/, um.to_sql)
    end

    describe "having" do
      it "sets having" do
        users_table = Table.new(:users)
        posts_table = Table.new(:posts)
        join_source = Arel::Nodes::InnerJoin.new(users_table, posts_table)

        update_manager = Arel::UpdateManager.new
        update_manager.table(join_source)
        update_manager.group(["posts.id"])
        update_manager.having("count(posts.id) >= 2")

        assert_equal(["count(posts.id) >= 2"], update_manager.ast.havings)
      end
    end

    describe "group" do
      it "adds columns to the AST when group value is a String" do
        users_table = Table.new(:users)
        posts_table = Table.new(:posts)
        join_source = Arel::Nodes::InnerJoin.new(users_table, posts_table)

        update_manager = Arel::UpdateManager.new
        update_manager.table(join_source)
        update_manager.group(["posts.id"])
        update_manager.having("count(posts.id) >= 2")

        assert_equal(1, update_manager.ast.groups.count)
        group_ast = update_manager.ast.groups.first
        _(group_ast).must_be_kind_of Nodes::Group
        assert_equal("posts.id", group_ast.expr)
        assert_equal(["count(posts.id) >= 2"], update_manager.ast.havings)
      end

      it "adds columns to the AST when group value is a Symbol" do
        users_table = Table.new(:users)
        posts_table = Table.new(:posts)
        join_source = Arel::Nodes::InnerJoin.new(users_table, posts_table)

        update_manager = Arel::UpdateManager.new
        update_manager.table(join_source)
        update_manager.group([:"posts.id"])
        update_manager.having("count(posts.id) >= 2")

        assert_equal(1, update_manager.ast.groups.count)
        group_ast = update_manager.ast.groups.first
        _(group_ast).must_be_kind_of Nodes::Group
        assert_equal("posts.id", group_ast.expr)
        assert_equal(["count(posts.id) >= 2"], update_manager.ast.havings)
      end
    end

    describe "set" do
      it "updates with null" do
        table = Table.new(:users)
        um = Arel::UpdateManager.new
        um.table table
        um.set [[table[:name], nil]]
        _(um.to_sql).must_be_like %{ UPDATE "users" SET "name" =  NULL }
      end

      it "takes a string" do
        table = Table.new(:users)
        um = Arel::UpdateManager.new
        um.table table
        um.set Nodes::SqlLiteral.new "foo = bar"
        _(um.to_sql).must_be_like %{ UPDATE "users" SET foo = bar }
      end

      it "takes a list of lists" do
        table = Table.new(:users)
        um = Arel::UpdateManager.new
        um.table table
        um.set [[table[:id], 1], [table[:name], "hello"]]
        _(um.to_sql).must_be_like %{
          UPDATE "users" SET "id" = 1, "name" =  'hello'
        }
      end

      it "chains" do
        table = Table.new(:users)
        um = Arel::UpdateManager.new
        _(um.set([[table[:id], 1], [table[:name], "hello"]])).must_equal um
      end
    end

    describe "table" do
      it "generates an update statement" do
        um = Arel::UpdateManager.new
        um.table Table.new(:users)
        _(um.to_sql).must_be_like %{ UPDATE "users" }
      end

      it "chains" do
        um = Arel::UpdateManager.new
        _(um.table(Table.new(:users))).must_equal um
      end

      it "generates an update statement with joins" do
        um = Arel::UpdateManager.new

        table = Table.new(:users)
        join_source = Arel::Nodes::JoinSource.new(
          table,
          [table.create_join(Table.new(:posts))]
        )

        um.table join_source
        _(um.to_sql).must_be_like %{ UPDATE "users" INNER JOIN "posts" }
      end
    end

    describe "where" do
      it "generates a where clause" do
        table = Table.new :users
        um = Arel::UpdateManager.new
        um.table table
        um.where table[:id].eq(1)
        _(um.to_sql).must_be_like %{
          UPDATE "users" WHERE "users"."id" = 1
        }
      end

      it "chains" do
        table = Table.new :users
        um = Arel::UpdateManager.new
        um.table table
        _(um.where(table[:id].eq(1))).must_equal um
      end
    end

    describe "key" do
      before do
        @table = Table.new :users
        @um = Arel::UpdateManager.new
        @um.key = @table[:foo]
      end

      it "can be set" do
        _(@um.ast.key).must_equal @table[:foo]
      end

      it "can be accessed" do
        _(@um.key).must_equal @table[:foo]
      end
    end

    describe "as" do
      it "makes an AS node by grouping the AST" do
        manager = Arel::UpdateManager.new
        as = manager.as(Arel.sql("foo"))
        assert_kind_of Arel::Nodes::Grouping, as.left
        assert_equal manager.ast, as.left.expr
        assert_equal "foo", as.right
      end

      it "converts right to SqlLiteral if a string" do
        manager = Arel::UpdateManager.new
        as = manager.as("foo")
        assert_kind_of Arel::Nodes::SqlLiteral, as.right
      end

      it "converts right to SqlLiteral if a symbol" do
        manager = Arel::UpdateManager.new
        as = manager.as(:foo)
        assert_kind_of Arel::Nodes::SqlLiteral, as.right
      end

      it "can make a subselect" do
        manager = Arel::UpdateManager.new
        manager.table Arel.sql("zomg")
        as = manager.as(Arel.sql("foo"))

        manager = Arel::SelectManager.new
        manager.project Arel.sql("name")
        manager.from as
        _(manager.to_sql).must_be_like "SELECT name FROM (UPDATE zomg) foo"
      end
    end
  end
end
