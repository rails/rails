# frozen_string_literal: true

require_relative "helper"

module Arel
  class SelectManagerTest < Arel::Test
    def test_join_sources
      manager = Arel::SelectManager.new
      manager.join_sources << Arel::Nodes::StringJoin.new(Nodes.build_quoted("foo"))
      assert_equal "SELECT FROM 'foo'", manager.to_sql
    end

    test "backwards compatibility project accepts symbols as sql literals" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.project :id
      manager.from table
      assert_like %{        SELECT id FROM "users"
      }, manager.to_sql
    end

    test "backwards compatibility order accepts symbols" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.project Nodes::SqlLiteral.new "*"
      manager.from table
      manager.order :foo
      assert_like %{ SELECT * FROM "users" ORDER BY foo }, manager.to_sql
    end

    test "backwards compatibility group takes a symbol" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.group :foo
      assert_like %{ SELECT FROM "users" GROUP BY foo }, manager.to_sql
    end

    test "backwards compatibility as makes an AS node by grouping the AST" do
      manager = Arel::SelectManager.new
      as = manager.as(Arel.sql("foo"))
      assert_kind_of Arel::Nodes::Grouping, as.left
      assert_equal manager.ast, as.left.expr
      assert_equal "foo", as.right
    end

    test "backwards compatibility as converts right to SqlLiteral if a string" do
      manager = Arel::SelectManager.new
      as = manager.as("foo")
      assert_kind_of Arel::Nodes::SqlLiteral, as.right
    end

    test "backwards compatibility as can make a subselect" do
      manager = Arel::SelectManager.new
      manager.project Arel.star
      manager.from Arel.sql("zomg")
      as = manager.as(Arel.sql("foo"))

      manager = Arel::SelectManager.new
      manager.project Arel.sql("name")
      manager.from as
      assert_like "SELECT name FROM (SELECT * FROM zomg) foo", manager.to_sql
    end

    test "backwards compatibility from ignores strings when table of same name exists" do
      table   = Table.new :users
      manager = Arel::SelectManager.new

      manager.from table
      manager.from "users"
      manager.project table["id"]
      assert_like 'SELECT "users"."id" FROM users', manager.to_sql
    end

    test "backwards compatibility from should support any ast" do
      table = Table.new :users
      manager1 = Arel::SelectManager.new

      manager2 = Arel::SelectManager.new
      manager2.project(Arel.sql("*"))
      manager2.from table

      manager1.project Arel.sql("lol")
      as = manager2.as Arel.sql("omg")
      manager1.from(as)

      assert_like %{        SELECT lol FROM (SELECT * FROM "users") omg
      }, manager1.to_sql
    end

    test "backwards compatibility having converts strings to SQLLiterals" do
      table = Table.new :users
      mgr = table.from
      mgr.having Arel.sql("foo")
      assert_like %{ SELECT FROM "users" HAVING foo }, mgr.to_sql
    end

    test "backwards compatibility having can have multiple items specified separately" do
      table = Table.new :users
      mgr = table.from
      mgr.having Arel.sql("foo")
      mgr.having Arel.sql("bar")
      assert_like %{ SELECT FROM "users" HAVING foo AND bar }, mgr.to_sql
    end

    test "backwards compatibility having can receive any node" do
      table = Table.new :users
      mgr = table.from
      mgr.having Arel::Nodes::And.new([Arel.sql("foo"), Arel.sql("bar")])
      assert_like %{ SELECT FROM "users" HAVING foo AND bar }, mgr.to_sql
    end

    test "backwards compatibility on converts to sqlliterals" do
      table = Table.new :users
      right = table.alias
      mgr   = table.from
      mgr.join(right).on("omg")
      assert_like %{ SELECT FROM "users" INNER JOIN "users" "users_2" ON omg }, mgr.to_sql
    end

    test "backwards compatibility on converts to sqlliterals with multiple items" do
      table = Table.new :users
      right = table.alias
      mgr   = table.from
      mgr.join(right).on("omg", "123")
      assert_like %{ SELECT FROM "users" INNER JOIN "users" "users_2" ON omg AND 123 }, mgr.to_sql
    end

    test "clone creates new cores" do
      table = Table.new :users, as: "foo"
      mgr = table.from
      m2 = mgr.clone
      m2.project "foo"
      assert_not_equal m2.to_sql, mgr.to_sql
    end

    test "clone makes updates to the correct copy" do
      table = Table.new :users, as: "foo"
      mgr = table.from
      m2 = mgr.clone
      m3 = m2.clone
      m2.project "foo"
      assert_not_equal m2.to_sql, mgr.to_sql
      assert_equal mgr.to_sql, m3.to_sql
    end

    test "initialize uses alias in sql" do
      table = Table.new :users, as: "foo"
      mgr = table.from
      mgr.skip 10
      assert_like %{ SELECT FROM "users" "foo" OFFSET 10 }, mgr.to_sql
    end

    test "skip should add an offset" do
      table = Table.new :users
      mgr = table.from
      mgr.skip 10
      assert_like %{ SELECT FROM "users" OFFSET 10 }, mgr.to_sql
    end

    test "skip should chain" do
      table = Table.new :users
      mgr = table.from
      assert_like %{ SELECT FROM "users" OFFSET 10 }, mgr.skip(10).to_sql
    end

    test "offset should add an offset" do
      table = Table.new :users
      mgr = table.from
      mgr.offset = 10
      assert_like %{ SELECT FROM "users" OFFSET 10 }, mgr.to_sql
    end

    test "offset should remove an offset" do
      table = Table.new :users
      mgr = table.from
      mgr.offset = 10
      assert_like %{ SELECT FROM "users" OFFSET 10 }, mgr.to_sql

      mgr.offset = nil
      assert_like %{ SELECT FROM "users" }, mgr.to_sql
    end

    test "offset should return the offset" do
      table = Table.new :users
      mgr = table.from
      mgr.offset = 10
      assert_equal 10, mgr.offset
    end

    test "exists should create an exists clause" do
      table = Table.new(:users)
      manager = Arel::SelectManager.new table
      manager.project Nodes::SqlLiteral.new "*"
      m2 = Arel::SelectManager.new
      m2.project manager.exists
      assert_like %{ SELECT EXISTS (#{manager.to_sql}) }, m2.to_sql
    end

    test "exists can be aliased" do
      table = Table.new(:users)
      manager = Arel::SelectManager.new table
      manager.project Nodes::SqlLiteral.new "*"
      m2 = Arel::SelectManager.new
      m2.project manager.exists.as("foo")
      assert_like %{ SELECT EXISTS (#{manager.to_sql}) AS foo }, m2.to_sql
    end


    test "union should union two managers" do
      table = Table.new :users
      @m1 = Arel::SelectManager.new table
      @m1.project Arel.star
      @m1.where(table[:age].lt(18))

      @m2 = Arel::SelectManager.new table
      @m2.project Arel.star
      @m2.where(table[:age].gt(99))
      # FIXME should this union "managers" or "statements" ?
      # FIXME this probably shouldn't return a node
      node = @m1.union @m2

      # maybe FIXME: decide when wrapper parens are needed
      assert_like %{        ( SELECT * FROM "users"  WHERE "users"."age" < 18 UNION SELECT * FROM "users"  WHERE "users"."age" > 99 )
      }, node.to_sql
    end

    test "union should union all" do
      table = Table.new :users
      @m1 = Arel::SelectManager.new table
      @m1.project Arel.star
      @m1.where(table[:age].lt(18))

      @m2 = Arel::SelectManager.new table
      @m2.project Arel.star
      @m2.where(table[:age].gt(99))
      node = @m1.union :all, @m2

      assert_like %{        ( SELECT * FROM "users"  WHERE "users"."age" < 18 UNION ALL SELECT * FROM "users"  WHERE "users"."age" > 99 )
      }, node.to_sql
    end


    test "intersect should intersect two managers" do
      table = Table.new :users
      @m1 = Arel::SelectManager.new table
      @m1.project Arel.star
      @m1.where(table[:age].gt(18))

      @m2 = Arel::SelectManager.new table
      @m2.project Arel.star
      @m2.where(table[:age].lt(99))
      # FIXME should this intersect "managers" or "statements" ?
      # FIXME this probably shouldn't return a node
      node = @m1.intersect @m2

      # maybe FIXME: decide when wrapper parens are needed
      assert_like %{        ( SELECT * FROM "users"  WHERE "users"."age" > 18 INTERSECT SELECT * FROM "users"  WHERE "users"."age" < 99 )
      }, node.to_sql
    end


    test "except should except two managers" do
      table = Table.new :users
      @m1 = Arel::SelectManager.new table
      @m1.project Arel.star
      @m1.where(table[:age].between(18..60))

      @m2 = Arel::SelectManager.new table
      @m2.project Arel.star
      @m2.where(table[:age].between(40..99))
      # FIXME should this except "managers" or "statements" ?
      # FIXME this probably shouldn't return a node
      node = @m1.except @m2

      # maybe FIXME: decide when wrapper parens are needed
      assert_like %{        ( SELECT * FROM "users"  WHERE "users"."age" BETWEEN 18 AND 60 EXCEPT SELECT * FROM "users"  WHERE "users"."age" BETWEEN 40 AND 99 )
      }, node.to_sql
    end

    test "with should support basic WITH" do
      users          = Table.new(:users)
      users_top      = Table.new(:users_top)
      comments       = Table.new(:comments)

      top            = users.project(users[:id]).where(users[:karma].gt(100))
      users_as       = Arel::Nodes::As.new(users_top, top)
      select_manager = comments.project(Arel.star).with(users_as)
                        .where(comments[:author_id].in(users_top.project(users_top[:id])))

      assert_like %{        WITH "users_top" AS (SELECT "users"."id" FROM "users" WHERE "users"."karma" > 100) SELECT * FROM "comments" WHERE "comments"."author_id" IN (SELECT "users_top"."id" FROM "users_top")
      }, select_manager.to_sql
    end

    test "with should support WITH RECURSIVE" do
      comments           = Table.new(:comments)
      comments_id        = comments[:id]
      comments_parent_id = comments[:parent_id]

      replies            = Table.new(:replies)
      replies_id         = replies[:id]

      non_recursive_term = Arel::SelectManager.new
      non_recursive_term.from(comments).project(comments_id, comments_parent_id).where(comments_id.eq 42)

      recursive_term = Arel::SelectManager.new
      recursive_term.from(comments).project(comments_id, comments_parent_id).join(replies).on(comments_parent_id.eq replies_id)

      union = non_recursive_term.union(recursive_term)

      as_statement = Arel::Nodes::As.new replies, union

      manager = Arel::SelectManager.new
      manager.with(:recursive, as_statement).from(replies).project(Arel.star)

      sql = manager.to_sql
      assert_like %{        WITH RECURSIVE "replies" AS (
            SELECT "comments"."id", "comments"."parent_id" FROM "comments" WHERE "comments"."id" = 42
          UNION
            SELECT "comments"."id", "comments"."parent_id" FROM "comments" INNER JOIN "replies" ON "comments"."parent_id" = "replies"."id"
        )
        SELECT * FROM "replies"
      }, sql
    end

    test "ast should return the ast" do
      table = Table.new :users
      mgr = table.from
      assert mgr.ast
    end

    test "taken should return limit" do
      manager = Arel::SelectManager.new
      manager.take 10
      assert_equal 10, manager.taken
    end

    # This should fail on other databases
    test "lock adds a lock node" do
      table = Table.new :users
      mgr = table.from
      assert_like %{ SELECT FROM "users" FOR UPDATE }, mgr.lock.to_sql
    end

    test "orders returns order clauses" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      order = table[:id]
      manager.order table[:id]
      assert_equal [order], manager.orders
    end

    test "order generates order clauses" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.project Nodes::SqlLiteral.new "*"
      manager.from table
      manager.order table[:id]
      assert_like %{        SELECT * FROM "users" ORDER BY "users"."id"
      }, manager.to_sql
    end

    # FIXME: I would like to deprecate this
    test "order takes *args" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.project Nodes::SqlLiteral.new "*"
      manager.from table
      manager.order table[:id], table[:name]
      assert_like %{        SELECT * FROM "users" ORDER BY "users"."id", "users"."name"
      }, manager.to_sql
    end

    test "order chains" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      assert_equal manager, manager.order(table[:id])
    end

    test "order has order attributes" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.project Nodes::SqlLiteral.new "*"
      manager.from table
      manager.order table[:id].desc
      assert_like %{        SELECT * FROM "users" ORDER BY "users"."id" DESC
      }, manager.to_sql
    end

    test "on takes two params" do
      left      = Table.new :users
      right     = left.alias
      predicate = left[:id].eq(right[:id])
      manager   = Arel::SelectManager.new

      manager.from left
      manager.join(right).on(predicate, predicate)
      assert_like %{         SELECT FROM "users"
           INNER JOIN "users" "users_2"
             ON "users"."id" = "users_2"."id" AND
             "users"."id" = "users_2"."id"
      }, manager.to_sql
    end

    test "on takes three params" do
      left      = Table.new :users
      right     = left.alias
      predicate = left[:id].eq(right[:id])
      manager   = Arel::SelectManager.new

      manager.from left
      manager.join(right).on(
        predicate,
        predicate,
        left[:name].eq(right[:name])
      )
      assert_like %{         SELECT FROM "users"
           INNER JOIN "users" "users_2"
             ON "users"."id" = "users_2"."id" AND
             "users"."id" = "users_2"."id" AND
             "users"."name" = "users_2"."name"
      }, manager.to_sql
    end

    test "should hand back froms" do
      relation = Arel::SelectManager.new
      assert_equal [], relation.froms
    end

    test "should create and nodes" do
      relation = Arel::SelectManager.new
      children = ["foo", "bar", "baz"]
      clause = relation.create_and children
      assert_kind_of Arel::Nodes::And, clause
      assert_equal children, clause.children
    end

    test "should create insert managers" do
      relation = Arel::SelectManager.new
      insert = relation.create_insert
      assert_kind_of Arel::InsertManager, insert
    end

    test "should create join nodes" do
      relation = Arel::SelectManager.new
      join = relation.create_join "foo", "bar"
      assert_kind_of Arel::Nodes::InnerJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    test "should create join nodes with a full outer join klass" do
      relation = Arel::SelectManager.new
      join = relation.create_join "foo", "bar", Arel::Nodes::FullOuterJoin
      assert_kind_of Arel::Nodes::FullOuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    test "should create join nodes with an outer join klass" do
      relation = Arel::SelectManager.new
      join = relation.create_join "foo", "bar", Arel::Nodes::OuterJoin
      assert_kind_of Arel::Nodes::OuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    test "should create join nodes with a right outer join klass" do
      relation = Arel::SelectManager.new
      join = relation.create_join "foo", "bar", Arel::Nodes::RightOuterJoin
      assert_kind_of Arel::Nodes::RightOuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    test "join responds to join" do
      left      = Table.new :users
      right     = left.alias
      predicate = left[:id].eq(right[:id])
      manager   = Arel::SelectManager.new

      manager.from left
      manager.join(right).on(predicate)
      assert_like %{         SELECT FROM "users"
           INNER JOIN "users" "users_2"
             ON "users"."id" = "users_2"."id"
      }, manager.to_sql
    end

    test "join takes a class" do
      left      = Table.new :users
      right     = left.alias
      predicate = left[:id].eq(right[:id])
      manager   = Arel::SelectManager.new

      manager.from left
      manager.join(right, Nodes::OuterJoin).on(predicate)
      assert_like %{         SELECT FROM "users"
           LEFT OUTER JOIN "users" "users_2"
             ON "users"."id" = "users_2"."id"
      }, manager.to_sql
    end

    test "join takes the full outer join class" do
      left      = Table.new :users
      right     = left.alias
      predicate = left[:id].eq(right[:id])
      manager   = Arel::SelectManager.new

      manager.from left
      manager.join(right, Nodes::FullOuterJoin).on(predicate)
      assert_like %{         SELECT FROM "users"
           FULL OUTER JOIN "users" "users_2"
             ON "users"."id" = "users_2"."id"
      }, manager.to_sql
    end

    test "join takes the right outer join class" do
      left      = Table.new :users
      right     = left.alias
      predicate = left[:id].eq(right[:id])
      manager   = Arel::SelectManager.new

      manager.from left
      manager.join(right, Nodes::RightOuterJoin).on(predicate)
      assert_like %{         SELECT FROM "users"
           RIGHT OUTER JOIN "users" "users_2"
             ON "users"."id" = "users_2"."id"
      }, manager.to_sql
    end

    test "join noops on nil" do
      manager = Arel::SelectManager.new
      assert_equal manager, manager.join(nil)
    end

    test "join raises EmptyJoinError on empty" do
      left      = Table.new :users
      manager   = Arel::SelectManager.new

      manager.from left
      assert_raises(EmptyJoinError) do
        manager.join("")
      end
    end

    test "outer join responds to join" do
      left      = Table.new :users
      right     = left.alias
      predicate = left[:id].eq(right[:id])
      manager   = Arel::SelectManager.new

      manager.from left
      manager.outer_join(right).on(predicate)
      assert_like %{         SELECT FROM "users"
           LEFT OUTER JOIN "users" "users_2"
             ON "users"."id" = "users_2"."id"
      }, manager.to_sql
    end

    test "outer join noops on nil" do
      manager = Arel::SelectManager.new
      assert_equal manager, manager.outer_join(nil)
    end

    test "joins returns inner join sql" do
      table   = Table.new :users
      aliaz   = table.alias
      manager = Arel::SelectManager.new
      manager.from Nodes::InnerJoin.new(aliaz, table[:id].eq(aliaz[:id]))
      assert_match 'INNER JOIN "users" "users_2" "users"."id" = "users_2"."id"',
                   manager.to_sql
    end

    test "joins returns outer join sql" do
      table   = Table.new :users
      aliaz   = table.alias
      manager = Arel::SelectManager.new
      manager.from Nodes::OuterJoin.new(aliaz, table[:id].eq(aliaz[:id]))
      assert_match 'LEFT OUTER JOIN "users" "users_2" "users"."id" = "users_2"."id"',
                   manager.to_sql
    end

    test "joins can have a non-table alias as relation name" do
      users    = Table.new :users
      comments = Table.new :comments

      counts = comments.from.
        group(comments[:user_id]).
        project(
          comments[:user_id].as("user_id"),
          comments[:user_id].count.as("count")
        ).as("counts")

      joins = users.join(counts).on(counts[:user_id].eq(10))
      assert_like %{        SELECT FROM "users" INNER JOIN (SELECT "comments"."user_id" AS user_id, COUNT("comments"."user_id") AS count FROM "comments" GROUP BY "comments"."user_id") counts ON counts."user_id" = 10
      }, joins.to_sql
    end

    test "joins joins itself" do
      left      = Table.new :users
      right     = left.alias
      predicate = left[:id].eq(right[:id])

      mgr = left.join(right)
      mgr.project Nodes::SqlLiteral.new("*")
      assert_equal mgr, mgr.on(predicate)

      assert_like %{         SELECT * FROM "users"
           INNER JOIN "users" "users_2"
             ON "users"."id" = "users_2"."id"
      }, mgr.to_sql
    end

    test "joins returns string join sql" do
      manager = Arel::SelectManager.new
      manager.from Nodes::StringJoin.new(Nodes.build_quoted("hello"))
      assert_match "'hello'", manager.to_sql
    end

    test "group takes an attribute" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.group table[:id]
      assert_like %{        SELECT FROM "users" GROUP BY "users"."id"
      }, manager.to_sql
    end

    test "group chains" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      assert_equal manager, manager.group(table[:id])
    end

    test "group takes multiple args" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.group table[:id], table[:name]
      assert_like %{        SELECT FROM "users" GROUP BY "users"."id", "users"."name"
      }, manager.to_sql
    end

    # FIXME: backwards compat
    test "group makes strings literals" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.group "foo"
      assert_like %{ SELECT FROM "users" GROUP BY foo }, manager.to_sql
    end

    test "window definition can be empty" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window")
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS ()
      }, manager.to_sql
    end

    test "window definition takes an order" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").order(table["foo"].asc)
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (ORDER BY "users"."foo" ASC)
      }, manager.to_sql
    end

    test "window definition takes an order with multiple columns" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").order(table["foo"].asc, table["bar"].desc)
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (ORDER BY "users"."foo" ASC, "users"."bar" DESC)
      }, manager.to_sql
    end

    test "window definition takes a partition" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").partition(table["bar"])
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (PARTITION BY "users"."bar")
      }, manager.to_sql
    end

    test "window definition takes a partition and an order" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").partition(table["foo"]).order(table["foo"].asc)
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (PARTITION BY "users"."foo"
          ORDER BY "users"."foo" ASC)
      }, manager.to_sql
    end

    test "window definition takes a partition with multiple columns" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").partition(table["bar"], table["baz"])
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (PARTITION BY "users"."bar", "users"."baz")
      }, manager.to_sql
    end

    test "window definition takes a rows frame, unbounded preceding" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").rows(Arel::Nodes::Preceding.new)
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (ROWS UNBOUNDED PRECEDING)
      }, manager.to_sql
    end

    test "window definition takes a rows frame, bounded preceding" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").rows(Arel::Nodes::Preceding.new(5))
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (ROWS 5 PRECEDING)
      }, manager.to_sql
    end

    test "window definition takes a rows frame, unbounded following" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").rows(Arel::Nodes::Following.new)
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (ROWS UNBOUNDED FOLLOWING)
      }, manager.to_sql
    end

    test "window definition takes a rows frame, bounded following" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").rows(Arel::Nodes::Following.new(5))
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (ROWS 5 FOLLOWING)
      }, manager.to_sql
    end

    test "window definition takes a rows frame, current row" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").rows(Arel::Nodes::CurrentRow.new)
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (ROWS CURRENT ROW)
      }, manager.to_sql
    end

    test "window definition takes a rows frame, between two delimiters" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      window = manager.window("a_window")
      window.frame(
        Arel::Nodes::Between.new(
          window.rows,
          Nodes::And.new([
            Arel::Nodes::Preceding.new,
            Arel::Nodes::CurrentRow.new
          ])))
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
      }, manager.to_sql
    end

    test "window definition takes a range frame, unbounded preceding" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").range(Arel::Nodes::Preceding.new)
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (RANGE UNBOUNDED PRECEDING)
      }, manager.to_sql
    end

    test "window definition takes a range frame, bounded preceding" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").range(Arel::Nodes::Preceding.new(5))
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (RANGE 5 PRECEDING)
      }, manager.to_sql
    end

    test "window definition takes a range frame, unbounded following" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").range(Arel::Nodes::Following.new)
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (RANGE UNBOUNDED FOLLOWING)
      }, manager.to_sql
    end

    test "window definition takes a range frame, bounded following" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").range(Arel::Nodes::Following.new(5))
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (RANGE 5 FOLLOWING)
      }, manager.to_sql
    end

    test "window definition takes a range frame, current row" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.window("a_window").range(Arel::Nodes::CurrentRow.new)
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (RANGE CURRENT ROW)
      }, manager.to_sql
    end

    test "window definition takes a range frame, between two delimiters" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      window = manager.window("a_window")
      window.frame(
        Arel::Nodes::Between.new(
          window.range,
          Nodes::And.new([
            Arel::Nodes::Preceding.new,
            Arel::Nodes::CurrentRow.new
          ])))
      assert_like %{        SELECT FROM "users" WINDOW "a_window" AS (RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
      }, manager.to_sql
    end

    test "delete copies from" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      stmt = manager.compile_delete

      assert_like %{ DELETE FROM "users" }, stmt.to_sql
    end

    test "delete copies where" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.where table[:id].eq 10
      stmt = manager.compile_delete

      assert_like %{        DELETE FROM "users" WHERE "users"."id" = 10
      }, stmt.to_sql
    end

    test "where_sql gives me back the where sql" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.where table[:id].eq 10
      assert_like %{ WHERE "users"."id" = 10 }, manager.where_sql
    end

    test "where_sql joins wheres with AND" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.where table[:id].eq 10
      manager.where table[:id].eq 11
      assert_like %{ WHERE "users"."id" = 10 AND "users"."id" = 11}, manager.where_sql
    end

    test "where_sql handles database-specific statements" do
      old_visitor = Table.engine.lease_connection.visitor
      Table.engine.lease_connection.visitor = Visitors::PostgreSQL.new Table.engine.lease_connection
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.where table[:id].eq 10
      manager.where table[:name].matches "foo%"
      assert_like %{ WHERE "users"."id" = 10 AND "users"."name" ILIKE 'foo%' }, manager.where_sql
      Table.engine.lease_connection.visitor = old_visitor
    end

    test "where_sql returns nil when there are no wheres" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      assert_nil manager.where_sql
    end

    test "update creates an update statement" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      stmt = manager.compile_update({ table[:id] => 1 }, Arel::Attributes::Attribute.new(table, "id"))

      assert_like %{        UPDATE "users" SET "id" = 1
      }, stmt.to_sql
    end

    test "update takes a string" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      stmt = manager.compile_update(Nodes::SqlLiteral.new("foo = bar"), Arel::Attributes::Attribute.new(table, "id"))

      assert_like %{ UPDATE "users" SET foo = bar }, stmt.to_sql
    end

    test "update copies limits" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.take 1
      stmt = manager.compile_update(Nodes::SqlLiteral.new("foo = bar"), Arel::Attributes::Attribute.new(table, "id"))
      stmt.key = table["id"]

      assert_like %{        UPDATE "users" SET foo = bar
        WHERE ("users"."id") IN (SELECT "users"."id" FROM "users" LIMIT 1)
      }, stmt.to_sql
    end

    test "update copies order" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from table
      manager.order :foo
      stmt = manager.compile_update(Nodes::SqlLiteral.new("foo = bar"), Arel::Attributes::Attribute.new(table, "id"))
      stmt.key = table["id"]

      assert_like %{        UPDATE "users" SET foo = bar
        WHERE ("users"."id") IN (SELECT "users"."id" FROM "users" ORDER BY foo)
      }, stmt.to_sql
    end

    test "update copies where clauses" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.where table[:id].eq 10
      manager.from table
      stmt = manager.compile_update({ table[:id] => 1 }, Arel::Attributes::Attribute.new(table, "id"))

      assert_like %{        UPDATE "users" SET "id" = 1 WHERE "users"."id" = 10
      }, stmt.to_sql
    end

    test "update copies where clauses when nesting is triggered" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.where table[:foo].eq 10
      manager.take 42
      manager.from table
      stmt = manager.compile_update({ table[:id] => 1 }, Arel::Attributes::Attribute.new(table, "id"))

      assert_like %{        UPDATE "users" SET "id" = 1 WHERE ("users"."id") IN (SELECT "users"."id" FROM "users" WHERE "users"."foo" = 10 LIMIT 42)
      }, stmt.to_sql
    end

    test "project takes sql literals" do
      manager = Arel::SelectManager.new
      manager.project Nodes::SqlLiteral.new "*"
      assert_like %{ SELECT * }, manager.to_sql
    end

    test "project takes multiple args" do
      manager = Arel::SelectManager.new
      manager.project Nodes::SqlLiteral.new("foo"),
        Nodes::SqlLiteral.new("bar")
      assert_like %{ SELECT foo, bar }, manager.to_sql
    end

    test "project takes strings" do
      manager = Arel::SelectManager.new
      manager.project "*"
      assert_like %{ SELECT * }, manager.to_sql
    end

    test "projections reads projections" do
      manager = Arel::SelectManager.new
      manager.project Arel.sql("foo"), Arel.sql("bar")
      assert_equal [Arel.sql("foo"), Arel.sql("bar")], manager.projections
    end

    test "projections= overwrites projections" do
      manager = Arel::SelectManager.new
      manager.project Arel.sql("foo")
      manager.projections = [Arel.sql("bar")]
      assert_like %{ SELECT bar }, manager.to_sql
    end

    test "take knows take" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from(table).project(table["id"])
      manager.where(table["id"].eq(1))
      manager.take 1

      assert_like %{        SELECT "users"."id"
        FROM "users"
        WHERE "users"."id" = 1
        LIMIT 1
      }, manager.to_sql
    end

    test "take chains" do
      manager = Arel::SelectManager.new
      assert_equal manager, manager.take(1)
    end

    test "take removes LIMIT when nil is passed" do
      manager = Arel::SelectManager.new
      manager.limit = 10
      assert_match("LIMIT", manager.to_sql)

      manager.limit = nil
      assert_no_match("LIMIT", manager.to_sql)
    end

    test "where knows where" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from(table).project(table["id"])
      manager.where(table["id"].eq(1))
      assert_like %{        SELECT "users"."id"
        FROM "users"
        WHERE "users"."id" = 1
      }, manager.to_sql
    end

    test "where chains" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      manager.from(table)
      assert_equal manager, manager.project(table["id"]).where(table["id"].eq 1)
    end

    test "from makes sql" do
      table   = Table.new :users
      manager = Arel::SelectManager.new

      manager.from table
      manager.project table["id"]
      assert_like 'SELECT "users"."id" FROM "users"', manager.to_sql
    end

    test "from chains" do
      table   = Table.new :users
      manager = Arel::SelectManager.new
      assert_equal manager, manager.from(table).project(table["id"])
      assert_like 'SELECT "users"."id" FROM "users"', manager.to_sql
    end

    test "source returns the join source of the select core" do
      manager = Arel::SelectManager.new
      assert_equal manager.ast.cores.last.source, manager.source
    end

    test "distinct sets the quantifier" do
      manager = Arel::SelectManager.new

      manager.distinct
      assert_equal Arel::Nodes::Distinct, manager.ast.cores.last.set_quantifier.class

      manager.distinct(false)
      assert_nil manager.ast.cores.last.set_quantifier
    end

    test "distinct chains" do
      manager = Arel::SelectManager.new
      assert_equal manager, manager.distinct
      assert_equal manager, manager.distinct(false)
    end

    test "distinct_on sets the quantifier" do
      manager = Arel::SelectManager.new
      table = Table.new :users

      manager.distinct_on(table["id"])
      assert_equal Arel::Nodes::DistinctOn.new(table["id"]), manager.ast.cores.last.set_quantifier

      manager.distinct_on(false)
      assert_nil manager.ast.cores.last.set_quantifier
    end

    test "distinct_on chains" do
      manager = Arel::SelectManager.new
      table = Table.new :users

      assert_equal manager, manager.distinct_on(table["id"])
      assert_equal manager, manager.distinct_on(false)
    end

    test "comment chains" do
      manager = Arel::SelectManager.new
      assert_equal manager, manager.comment("selecting")
    end

    test "comment appends a comment to the generated query" do
      manager = Arel::SelectManager.new
      table = Table.new :users
      manager.from(table).project(table["id"])

      manager.comment("selecting")
      assert_like %{        SELECT "users"."id" FROM "users" /* selecting */
      }, manager.to_sql

      manager.comment("selecting", "with", "comment")
      assert_like %{        SELECT "users"."id" FROM "users" /* selecting */ /* with */ /* comment */
      }, manager.to_sql
    end
  end
end
