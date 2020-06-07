# frozen_string_literal: true

require_relative "helper"

module Arel
  class SelectManagerTest < Arel::Spec
    def test_join_sources
      manager = Arel::SelectManager.new
      manager.join_sources << Arel::Nodes::StringJoin.new(Nodes.build_quoted("foo"))
      assert_equal "SELECT FROM 'foo'", manager.to_sql
    end

    describe "backwards compatibility" do
      describe "project" do
        it "accepts symbols as sql literals" do
          table   = Table.new :users
          manager = Arel::SelectManager.new
          manager.project :id
          manager.from table
          _(manager.to_sql).must_be_like %{
            SELECT id FROM "users"
          }
        end
      end

      describe "order" do
        it "accepts symbols" do
          table   = Table.new :users
          manager = Arel::SelectManager.new
          manager.project Nodes::SqlLiteral.new "*"
          manager.from table
          manager.order :foo
          _(manager.to_sql).must_be_like %{ SELECT * FROM "users" ORDER BY foo }
        end
      end

      describe "group" do
        it "takes a symbol" do
          table   = Table.new :users
          manager = Arel::SelectManager.new
          manager.from table
          manager.group :foo
          _(manager.to_sql).must_be_like %{ SELECT FROM "users" GROUP BY foo }
        end
      end

      describe "as" do
        it "makes an AS node by grouping the AST" do
          manager = Arel::SelectManager.new
          as = manager.as(Arel.sql("foo"))
          assert_kind_of Arel::Nodes::Grouping, as.left
          assert_equal manager.ast, as.left.expr
          assert_equal "foo", as.right
        end

        it "converts right to SqlLiteral if a string" do
          manager = Arel::SelectManager.new
          as = manager.as("foo")
          assert_kind_of Arel::Nodes::SqlLiteral, as.right
        end

        it "can make a subselect" do
          manager = Arel::SelectManager.new
          manager.project Arel.star
          manager.from Arel.sql("zomg")
          as = manager.as(Arel.sql("foo"))

          manager = Arel::SelectManager.new
          manager.project Arel.sql("name")
          manager.from as
          _(manager.to_sql).must_be_like "SELECT name FROM (SELECT * FROM zomg) foo"
        end
      end

      describe "from" do
        it "ignores strings when table of same name exists" do
          table   = Table.new :users
          manager = Arel::SelectManager.new

          manager.from table
          manager.from "users"
          manager.project table["id"]
          _(manager.to_sql).must_be_like 'SELECT "users"."id" FROM users'
        end

        it "should support any ast" do
          table = Table.new :users
          manager1 = Arel::SelectManager.new

          manager2 = Arel::SelectManager.new
          manager2.project(Arel.sql("*"))
          manager2.from table

          manager1.project Arel.sql("lol")
          as = manager2.as Arel.sql("omg")
          manager1.from(as)

          _(manager1.to_sql).must_be_like %{
            SELECT lol FROM (SELECT * FROM "users") omg
          }
        end
      end

      describe "having" do
        it "converts strings to SQLLiterals" do
          table = Table.new :users
          mgr = table.from
          mgr.having Arel.sql("foo")
          _(mgr.to_sql).must_be_like %{ SELECT FROM "users" HAVING foo }
        end

        it "can have multiple items specified separately" do
          table = Table.new :users
          mgr = table.from
          mgr.having Arel.sql("foo")
          mgr.having Arel.sql("bar")
          _(mgr.to_sql).must_be_like %{ SELECT FROM "users" HAVING foo AND bar }
        end

        it "can receive any node" do
          table = Table.new :users
          mgr = table.from
          mgr.having Arel::Nodes::And.new([Arel.sql("foo"), Arel.sql("bar")])
          _(mgr.to_sql).must_be_like %{ SELECT FROM "users" HAVING foo AND bar }
        end
      end

      describe "on" do
        it "converts to sqlliterals" do
          table = Table.new :users
          right = table.alias
          mgr   = table.from
          mgr.join(right).on("omg")
          _(mgr.to_sql).must_be_like %{ SELECT FROM "users" INNER JOIN "users" "users_2" ON omg }
        end

        it "converts to sqlliterals with multiple items" do
          table = Table.new :users
          right = table.alias
          mgr   = table.from
          mgr.join(right).on("omg", "123")
          _(mgr.to_sql).must_be_like %{ SELECT FROM "users" INNER JOIN "users" "users_2" ON omg AND 123 }
        end
      end
    end

    describe "clone" do
      it "creates new cores" do
        table = Table.new :users, as: "foo"
        mgr = table.from
        m2 = mgr.clone
        m2.project "foo"
        _(mgr.to_sql).wont_equal m2.to_sql
      end

      it "makes updates to the correct copy" do
        table = Table.new :users, as: "foo"
        mgr = table.from
        m2 = mgr.clone
        m3 = m2.clone
        m2.project "foo"
        _(mgr.to_sql).wont_equal m2.to_sql
        _(m3.to_sql).must_equal mgr.to_sql
      end
    end

    describe "initialize" do
      it "uses alias in sql" do
        table = Table.new :users, as: "foo"
        mgr = table.from
        mgr.skip 10
        _(mgr.to_sql).must_be_like %{ SELECT FROM "users" "foo" OFFSET 10 }
      end
    end

    describe "skip" do
      it "should add an offset" do
        table = Table.new :users
        mgr = table.from
        mgr.skip 10
        _(mgr.to_sql).must_be_like %{ SELECT FROM "users" OFFSET 10 }
      end

      it "should chain" do
        table = Table.new :users
        mgr = table.from
        _(mgr.skip(10).to_sql).must_be_like %{ SELECT FROM "users" OFFSET 10 }
      end
    end

    describe "offset" do
      it "should add an offset" do
        table = Table.new :users
        mgr = table.from
        mgr.offset = 10
        _(mgr.to_sql).must_be_like %{ SELECT FROM "users" OFFSET 10 }
      end

      it "should remove an offset" do
        table = Table.new :users
        mgr = table.from
        mgr.offset = 10
        _(mgr.to_sql).must_be_like %{ SELECT FROM "users" OFFSET 10 }

        mgr.offset = nil
        _(mgr.to_sql).must_be_like %{ SELECT FROM "users" }
      end

      it "should return the offset" do
        table = Table.new :users
        mgr = table.from
        mgr.offset = 10
        assert_equal 10, mgr.offset
      end
    end

    describe "exists" do
      it "should create an exists clause" do
        table = Table.new(:users)
        manager = Arel::SelectManager.new table
        manager.project Nodes::SqlLiteral.new "*"
        m2 = Arel::SelectManager.new
        m2.project manager.exists
        _(m2.to_sql).must_be_like %{ SELECT EXISTS (#{manager.to_sql}) }
      end

      it "can be aliased" do
        table = Table.new(:users)
        manager = Arel::SelectManager.new table
        manager.project Nodes::SqlLiteral.new "*"
        m2 = Arel::SelectManager.new
        m2.project manager.exists.as("foo")
        _(m2.to_sql).must_be_like %{ SELECT EXISTS (#{manager.to_sql}) AS foo }
      end
    end

    describe "union" do
      before do
        table = Table.new :users
        @m1 = Arel::SelectManager.new table
        @m1.project Arel.star
        @m1.where(table[:age].lt(18))

        @m2 = Arel::SelectManager.new table
        @m2.project Arel.star
        @m2.where(table[:age].gt(99))
      end

      it "should union two managers" do
        # FIXME should this union "managers" or "statements" ?
        # FIXME this probably shouldn't return a node
        node = @m1.union @m2

        # maybe FIXME: decide when wrapper parens are needed
        _(node.to_sql).must_be_like %{
          ( SELECT * FROM "users"  WHERE "users"."age" < 18 UNION SELECT * FROM "users"  WHERE "users"."age" > 99 )
        }
      end

      it "should union all" do
        node = @m1.union :all, @m2

        _(node.to_sql).must_be_like %{
          ( SELECT * FROM "users"  WHERE "users"."age" < 18 UNION ALL SELECT * FROM "users"  WHERE "users"."age" > 99 )
        }
      end
    end

    describe "intersect" do
      before do
        table = Table.new :users
        @m1 = Arel::SelectManager.new table
        @m1.project Arel.star
        @m1.where(table[:age].gt(18))

        @m2 = Arel::SelectManager.new table
        @m2.project Arel.star
        @m2.where(table[:age].lt(99))
      end

      it "should intersect two managers" do
        # FIXME should this intersect "managers" or "statements" ?
        # FIXME this probably shouldn't return a node
        node = @m1.intersect @m2

        # maybe FIXME: decide when wrapper parens are needed
        _(node.to_sql).must_be_like %{
          ( SELECT * FROM "users"  WHERE "users"."age" > 18 INTERSECT SELECT * FROM "users"  WHERE "users"."age" < 99 )
        }
      end
    end

    describe "except" do
      before do
        table = Table.new :users
        @m1 = Arel::SelectManager.new table
        @m1.project Arel.star
        @m1.where(table[:age].between(18..60))

        @m2 = Arel::SelectManager.new table
        @m2.project Arel.star
        @m2.where(table[:age].between(40..99))
      end

      it "should except two managers" do
        # FIXME should this except "managers" or "statements" ?
        # FIXME this probably shouldn't return a node
        node = @m1.except @m2

        # maybe FIXME: decide when wrapper parens are needed
        _(node.to_sql).must_be_like %{
          ( SELECT * FROM "users"  WHERE "users"."age" BETWEEN 18 AND 60 EXCEPT SELECT * FROM "users"  WHERE "users"."age" BETWEEN 40 AND 99 )
        }
      end
    end

    describe "with" do
      it "should support basic WITH" do
        users          = Table.new(:users)
        users_top      = Table.new(:users_top)
        comments       = Table.new(:comments)

        top            = users.project(users[:id]).where(users[:karma].gt(100))
        users_as       = Arel::Nodes::As.new(users_top, top)
        select_manager = comments.project(Arel.star).with(users_as)
                          .where(comments[:author_id].in(users_top.project(users_top[:id])))

        _(select_manager.to_sql).must_be_like %{
          WITH "users_top" AS (SELECT "users"."id" FROM "users" WHERE "users"."karma" > 100) SELECT * FROM "comments" WHERE "comments"."author_id" IN (SELECT "users_top"."id" FROM "users_top")
        }
      end

      it "should support WITH RECURSIVE" do
        comments           = Table.new(:comments)
        comments_id        = comments[:id]
        comments_parent_id = comments[:parent_id]

        replies            = Table.new(:replies)
        replies_id         = replies[:id]

        recursive_term = Arel::SelectManager.new
        recursive_term.from(comments).project(comments_id, comments_parent_id).where(comments_id.eq 42)

        non_recursive_term = Arel::SelectManager.new
        non_recursive_term.from(comments).project(comments_id, comments_parent_id).join(replies).on(comments_parent_id.eq replies_id)

        union = recursive_term.union(non_recursive_term)

        as_statement = Arel::Nodes::As.new replies, union

        manager = Arel::SelectManager.new
        manager.with(:recursive, as_statement).from(replies).project(Arel.star)

        sql = manager.to_sql
        _(sql).must_be_like %{
          WITH RECURSIVE "replies" AS (
              SELECT "comments"."id", "comments"."parent_id" FROM "comments" WHERE "comments"."id" = 42
            UNION
              SELECT "comments"."id", "comments"."parent_id" FROM "comments" INNER JOIN "replies" ON "comments"."parent_id" = "replies"."id"
          )
          SELECT * FROM "replies"
        }
      end
    end

    describe "ast" do
      it "should return the ast" do
        table = Table.new :users
        mgr = table.from
        assert mgr.ast
      end
    end

    describe "taken" do
      it "should return limit" do
        manager = Arel::SelectManager.new
        manager.take 10
        _(manager.taken).must_equal 10
      end
    end

    describe "lock" do
      # This should fail on other databases
      it "adds a lock node" do
        table = Table.new :users
        mgr = table.from
        _(mgr.lock.to_sql).must_be_like %{ SELECT FROM "users" FOR UPDATE }
      end
    end

    describe "orders" do
      it "returns order clauses" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        order = table[:id]
        manager.order table[:id]
        _(manager.orders).must_equal [order]
      end
    end

    describe "order" do
      it "generates order clauses" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.project Nodes::SqlLiteral.new "*"
        manager.from table
        manager.order table[:id]
        _(manager.to_sql).must_be_like %{
          SELECT * FROM "users" ORDER BY "users"."id"
        }
      end

      # FIXME: I would like to deprecate this
      it "takes *args" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.project Nodes::SqlLiteral.new "*"
        manager.from table
        manager.order table[:id], table[:name]
        _(manager.to_sql).must_be_like %{
          SELECT * FROM "users" ORDER BY "users"."id", "users"."name"
        }
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        _(manager.order(table[:id])).must_equal manager
      end

      it "has order attributes" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.project Nodes::SqlLiteral.new "*"
        manager.from table
        manager.order table[:id].desc
        _(manager.to_sql).must_be_like %{
          SELECT * FROM "users" ORDER BY "users"."id" DESC
        }
      end
    end

    describe "on" do
      it "takes two params" do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new

        manager.from left
        manager.join(right).on(predicate, predicate)
        _(manager.to_sql).must_be_like %{
           SELECT FROM "users"
             INNER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id" AND
               "users"."id" = "users_2"."id"
        }
      end

      it "takes three params" do
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
        _(manager.to_sql).must_be_like %{
           SELECT FROM "users"
             INNER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id" AND
               "users"."id" = "users_2"."id" AND
               "users"."name" = "users_2"."name"
        }
      end
    end

    it "should hand back froms" do
      relation = Arel::SelectManager.new
      assert_equal [], relation.froms
    end

    it "should create and nodes" do
      relation = Arel::SelectManager.new
      children = ["foo", "bar", "baz"]
      clause = relation.create_and children
      assert_kind_of Arel::Nodes::And, clause
      assert_equal children, clause.children
    end

    it "should create insert managers" do
      relation = Arel::SelectManager.new
      insert = relation.create_insert
      assert_kind_of Arel::InsertManager, insert
    end

    it "should create join nodes" do
      relation = Arel::SelectManager.new
      join = relation.create_join "foo", "bar"
      assert_kind_of Arel::Nodes::InnerJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    it "should create join nodes with a full outer join klass" do
      relation = Arel::SelectManager.new
      join = relation.create_join "foo", "bar", Arel::Nodes::FullOuterJoin
      assert_kind_of Arel::Nodes::FullOuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    it "should create join nodes with an outer join klass" do
      relation = Arel::SelectManager.new
      join = relation.create_join "foo", "bar", Arel::Nodes::OuterJoin
      assert_kind_of Arel::Nodes::OuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    it "should create join nodes with a right outer join klass" do
      relation = Arel::SelectManager.new
      join = relation.create_join "foo", "bar", Arel::Nodes::RightOuterJoin
      assert_kind_of Arel::Nodes::RightOuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    describe "join" do
      it "responds to join" do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new

        manager.from left
        manager.join(right).on(predicate)
        _(manager.to_sql).must_be_like %{
           SELECT FROM "users"
             INNER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end

      it "takes a class" do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new

        manager.from left
        manager.join(right, Nodes::OuterJoin).on(predicate)
        _(manager.to_sql).must_be_like %{
           SELECT FROM "users"
             LEFT OUTER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end

      it "takes the full outer join class" do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new

        manager.from left
        manager.join(right, Nodes::FullOuterJoin).on(predicate)
        _(manager.to_sql).must_be_like %{
           SELECT FROM "users"
             FULL OUTER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end

      it "takes the right outer join class" do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new

        manager.from left
        manager.join(right, Nodes::RightOuterJoin).on(predicate)
        _(manager.to_sql).must_be_like %{
           SELECT FROM "users"
             RIGHT OUTER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end

      it "noops on nil" do
        manager = Arel::SelectManager.new
        _(manager.join(nil)).must_equal manager
      end

      it "raises EmptyJoinError on empty" do
        left      = Table.new :users
        manager   = Arel::SelectManager.new

        manager.from left
        assert_raises(EmptyJoinError) do
          manager.join("")
        end
      end
    end

    describe "outer join" do
      it "responds to join" do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new

        manager.from left
        manager.outer_join(right).on(predicate)
        _(manager.to_sql).must_be_like %{
           SELECT FROM "users"
             LEFT OUTER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end

      it "noops on nil" do
        manager = Arel::SelectManager.new
        _(manager.outer_join(nil)).must_equal manager
      end
    end

    describe "joins" do
      it "returns inner join sql" do
        table   = Table.new :users
        aliaz   = table.alias
        manager = Arel::SelectManager.new
        manager.from Nodes::InnerJoin.new(aliaz, table[:id].eq(aliaz[:id]))
        assert_match 'INNER JOIN "users" "users_2" "users"."id" = "users_2"."id"',
                     manager.to_sql
      end

      it "returns outer join sql" do
        table   = Table.new :users
        aliaz   = table.alias
        manager = Arel::SelectManager.new
        manager.from Nodes::OuterJoin.new(aliaz, table[:id].eq(aliaz[:id]))
        assert_match 'LEFT OUTER JOIN "users" "users_2" "users"."id" = "users_2"."id"',
                     manager.to_sql
      end

      it "can have a non-table alias as relation name" do
        users    = Table.new :users
        comments = Table.new :comments

        counts = comments.from.
          group(comments[:user_id]).
          project(
            comments[:user_id].as("user_id"),
            comments[:user_id].count.as("count")
          ).as("counts")

        joins = users.join(counts).on(counts[:user_id].eq(10))
        _(joins.to_sql).must_be_like %{
          SELECT FROM "users" INNER JOIN (SELECT "comments"."user_id" AS user_id, COUNT("comments"."user_id") AS count FROM "comments" GROUP BY "comments"."user_id") counts ON counts."user_id" = 10
        }
      end

      it "joins itself" do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])

        mgr = left.join(right)
        mgr.project Nodes::SqlLiteral.new("*")
        _(mgr.on(predicate)).must_equal mgr

        _(mgr.to_sql).must_be_like %{
           SELECT * FROM "users"
             INNER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end

      it "returns string join sql" do
        manager = Arel::SelectManager.new
        manager.from Nodes::StringJoin.new(Nodes.build_quoted("hello"))
        assert_match "'hello'", manager.to_sql
      end
    end

    describe "group" do
      it "takes an attribute" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.group table[:id]
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" GROUP BY "users"."id"
        }
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        _(manager.group(table[:id])).must_equal manager
      end

      it "takes multiple args" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.group table[:id], table[:name]
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" GROUP BY "users"."id", "users"."name"
        }
      end

      # FIXME: backwards compat
      it "makes strings literals" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.group "foo"
        _(manager.to_sql).must_be_like %{ SELECT FROM "users" GROUP BY foo }
      end
    end

    describe "window definition" do
      it "can be empty" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window")
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS ()
        }
      end

      it "takes an order" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").order(table["foo"].asc)
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ORDER BY "users"."foo" ASC)
        }
      end

      it "takes an order with multiple columns" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").order(table["foo"].asc, table["bar"].desc)
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ORDER BY "users"."foo" ASC, "users"."bar" DESC)
        }
      end

      it "takes a partition" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").partition(table["bar"])
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (PARTITION BY "users"."bar")
        }
      end

      it "takes a partition and an order" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").partition(table["foo"]).order(table["foo"].asc)
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (PARTITION BY "users"."foo"
            ORDER BY "users"."foo" ASC)
        }
      end

      it "takes a partition with multiple columns" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").partition(table["bar"], table["baz"])
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (PARTITION BY "users"."bar", "users"."baz")
        }
      end

      it "takes a rows frame, unbounded preceding" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").rows(Arel::Nodes::Preceding.new)
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS UNBOUNDED PRECEDING)
        }
      end

      it "takes a rows frame, bounded preceding" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").rows(Arel::Nodes::Preceding.new(5))
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS 5 PRECEDING)
        }
      end

      it "takes a rows frame, unbounded following" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").rows(Arel::Nodes::Following.new)
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS UNBOUNDED FOLLOWING)
        }
      end

      it "takes a rows frame, bounded following" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").rows(Arel::Nodes::Following.new(5))
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS 5 FOLLOWING)
        }
      end

      it "takes a rows frame, current row" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").rows(Arel::Nodes::CurrentRow.new)
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS CURRENT ROW)
        }
      end

      it "takes a rows frame, between two delimiters" do
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
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        }
      end

      it "takes a range frame, unbounded preceding" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").range(Arel::Nodes::Preceding.new)
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE UNBOUNDED PRECEDING)
        }
      end

      it "takes a range frame, bounded preceding" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").range(Arel::Nodes::Preceding.new(5))
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE 5 PRECEDING)
        }
      end

      it "takes a range frame, unbounded following" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").range(Arel::Nodes::Following.new)
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE UNBOUNDED FOLLOWING)
        }
      end

      it "takes a range frame, bounded following" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").range(Arel::Nodes::Following.new(5))
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE 5 FOLLOWING)
        }
      end

      it "takes a range frame, current row" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.window("a_window").range(Arel::Nodes::CurrentRow.new)
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE CURRENT ROW)
        }
      end

      it "takes a range frame, between two delimiters" do
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
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        }
      end
    end

    describe "delete" do
      it "copies from" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        stmt = manager.compile_delete

        _(stmt.to_sql).must_be_like %{ DELETE FROM "users" }
      end

      it "copies where" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.where table[:id].eq 10
        stmt = manager.compile_delete

        _(stmt.to_sql).must_be_like %{
          DELETE FROM "users" WHERE "users"."id" = 10
        }
      end
    end

    describe "where_sql" do
      it "gives me back the where sql" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.where table[:id].eq 10
        _(manager.where_sql).must_be_like %{ WHERE "users"."id" = 10 }
      end

      it "joins wheres with AND" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.where table[:id].eq 10
        manager.where table[:id].eq 11
        _(manager.where_sql).must_be_like %{ WHERE "users"."id" = 10 AND "users"."id" = 11}
      end

      it "handles database specific statements" do
        old_visitor = Table.engine.connection.visitor
        Table.engine.connection.visitor = Visitors::PostgreSQL.new Table.engine.connection
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.where table[:id].eq 10
        manager.where table[:name].matches "foo%"
        _(manager.where_sql).must_be_like %{ WHERE "users"."id" = 10 AND "users"."name" ILIKE 'foo%' }
        Table.engine.connection.visitor = old_visitor
      end

      it "returns nil when there are no wheres" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        _(manager.where_sql).must_be_nil
      end
    end

    describe "update" do
      it "creates an update statement" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        stmt = manager.compile_update({ table[:id] => 1 }, Arel::Attributes::Attribute.new(table, "id"))

        _(stmt.to_sql).must_be_like %{
          UPDATE "users" SET "id" = 1
        }
      end

      it "takes a string" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        stmt = manager.compile_update(Nodes::SqlLiteral.new("foo = bar"), Arel::Attributes::Attribute.new(table, "id"))

        _(stmt.to_sql).must_be_like %{ UPDATE "users" SET foo = bar }
      end

      it "copies limits" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.take 1
        stmt = manager.compile_update(Nodes::SqlLiteral.new("foo = bar"), Arel::Attributes::Attribute.new(table, "id"))
        stmt.key = table["id"]

        _(stmt.to_sql).must_be_like %{
          UPDATE "users" SET foo = bar
          WHERE "users"."id" IN (SELECT "users"."id" FROM "users" LIMIT 1)
        }
      end

      it "copies order" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from table
        manager.order :foo
        stmt = manager.compile_update(Nodes::SqlLiteral.new("foo = bar"), Arel::Attributes::Attribute.new(table, "id"))
        stmt.key = table["id"]

        _(stmt.to_sql).must_be_like %{
          UPDATE "users" SET foo = bar
          WHERE "users"."id" IN (SELECT "users"."id" FROM "users" ORDER BY foo)
        }
      end

      it "copies where clauses" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.where table[:id].eq 10
        manager.from table
        stmt = manager.compile_update({ table[:id] => 1 }, Arel::Attributes::Attribute.new(table, "id"))

        _(stmt.to_sql).must_be_like %{
          UPDATE "users" SET "id" = 1 WHERE "users"."id" = 10
        }
      end

      it "copies where clauses when nesting is triggered" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.where table[:foo].eq 10
        manager.take 42
        manager.from table
        stmt = manager.compile_update({ table[:id] => 1 }, Arel::Attributes::Attribute.new(table, "id"))

        _(stmt.to_sql).must_be_like %{
          UPDATE "users" SET "id" = 1 WHERE "users"."id" IN (SELECT "users"."id" FROM "users" WHERE "users"."foo" = 10 LIMIT 42)
        }
      end
    end

    describe "project" do
      it "takes sql literals" do
        manager = Arel::SelectManager.new
        manager.project Nodes::SqlLiteral.new "*"
        _(manager.to_sql).must_be_like %{ SELECT * }
      end

      it "takes multiple args" do
        manager = Arel::SelectManager.new
        manager.project Nodes::SqlLiteral.new("foo"),
          Nodes::SqlLiteral.new("bar")
        _(manager.to_sql).must_be_like %{ SELECT foo, bar }
      end

      it "takes strings" do
        manager = Arel::SelectManager.new
        manager.project "*"
        _(manager.to_sql).must_be_like %{ SELECT * }
      end
    end

    describe "projections" do
      it "reads projections" do
        manager = Arel::SelectManager.new
        manager.project Arel.sql("foo"), Arel.sql("bar")
        _(manager.projections).must_equal [Arel.sql("foo"), Arel.sql("bar")]
      end
    end

    describe "projections=" do
      it "overwrites projections" do
        manager = Arel::SelectManager.new
        manager.project Arel.sql("foo")
        manager.projections = [Arel.sql("bar")]
        _(manager.to_sql).must_be_like %{ SELECT bar }
      end
    end

    describe "take" do
      it "knows take" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from(table).project(table["id"])
        manager.where(table["id"].eq(1))
        manager.take 1

        _(manager.to_sql).must_be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
          LIMIT 1
        }
      end

      it "chains" do
        manager = Arel::SelectManager.new
        _(manager.take(1)).must_equal manager
      end

      it "removes LIMIT when nil is passed" do
        manager = Arel::SelectManager.new
        manager.limit = 10
        assert_match("LIMIT", manager.to_sql)

        manager.limit = nil
        assert_no_match("LIMIT", manager.to_sql)
      end
    end

    describe "where" do
      it "knows where" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from(table).project(table["id"])
        manager.where(table["id"].eq(1))
        _(manager.to_sql).must_be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
        }
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        manager.from(table)
        _(manager.project(table["id"]).where(table["id"].eq 1)).must_equal manager
      end
    end

    describe "from" do
      it "makes sql" do
        table   = Table.new :users
        manager = Arel::SelectManager.new

        manager.from table
        manager.project table["id"]
        _(manager.to_sql).must_be_like 'SELECT "users"."id" FROM "users"'
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new
        _(manager.from(table).project(table["id"])).must_equal manager
        _(manager.to_sql).must_be_like 'SELECT "users"."id" FROM "users"'
      end
    end

    describe "source" do
      it "returns the join source of the select core" do
        manager = Arel::SelectManager.new
        _(manager.source).must_equal manager.ast.cores.last.source
      end
    end

    describe "distinct" do
      it "sets the quantifier" do
        manager = Arel::SelectManager.new

        manager.distinct
        _(manager.ast.cores.last.set_quantifier.class).must_equal Arel::Nodes::Distinct

        manager.distinct(false)
        _(manager.ast.cores.last.set_quantifier).must_be_nil
      end

      it "chains" do
        manager = Arel::SelectManager.new
        _(manager.distinct).must_equal manager
        _(manager.distinct(false)).must_equal manager
      end
    end

    describe "distinct_on" do
      it "sets the quantifier" do
        manager = Arel::SelectManager.new
        table = Table.new :users

        manager.distinct_on(table["id"])
        _(manager.ast.cores.last.set_quantifier).must_equal Arel::Nodes::DistinctOn.new(table["id"])

        manager.distinct_on(false)
        _(manager.ast.cores.last.set_quantifier).must_be_nil
      end

      it "chains" do
        manager = Arel::SelectManager.new
        table = Table.new :users

        _(manager.distinct_on(table["id"])).must_equal manager
        _(manager.distinct_on(false)).must_equal manager
      end
    end

    describe "comment" do
      it "chains" do
        manager = Arel::SelectManager.new
        _(manager.comment("selecting")).must_equal manager
      end

      it "appends a comment to the generated query" do
        manager = Arel::SelectManager.new
        table = Table.new :users
        manager.from(table).project(table["id"])

        manager.comment("selecting")
        _(manager.to_sql).must_be_like %{
          SELECT "users"."id" FROM "users" /* selecting */
        }

        manager.comment("selecting", "with", "comment")
        _(manager.to_sql).must_be_like %{
          SELECT "users"."id" FROM "users" /* selecting */ /* with */ /* comment */
        }
      end
    end
  end
end
