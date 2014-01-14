require 'helper'

module Arel

  describe 'select manager' do
    def test_join_sources
      manager = Arel::SelectManager.new Table.engine
      manager.join_sources << Arel::Nodes::StringJoin.new('foo')
      assert_equal "SELECT FROM 'foo'", manager.to_sql
    end

    def test_manager_stores_bind_values
      manager = Arel::SelectManager.new Table.engine
      assert_equal [], manager.bind_values
      manager.bind_values = [1]
      assert_equal [1], manager.bind_values
    end

    describe 'backwards compatibility' do
      describe 'project' do
        it 'accepts symbols as sql literals' do
          table   = Table.new :users
          manager = Arel::SelectManager.new Table.engine
          manager.project :id
          manager.from table
          manager.to_sql.must_be_like %{
            SELECT id FROM "users"
          }
        end
      end

      describe 'order' do
        it 'accepts symbols' do
          table   = Table.new :users
          manager = Arel::SelectManager.new Table.engine
          manager.project SqlLiteral.new '*'
          manager.from table
          manager.order :foo
          manager.to_sql.must_be_like %{ SELECT * FROM "users" ORDER BY foo }
        end
      end

      describe 'group' do
        it 'takes a symbol' do
          table   = Table.new :users
          manager = Arel::SelectManager.new Table.engine
          manager.from table
          manager.group :foo
          manager.to_sql.must_be_like %{ SELECT FROM "users" GROUP BY foo }
        end
      end

      describe 'as' do
        it 'makes an AS node by grouping the AST' do
          manager = Arel::SelectManager.new Table.engine
          as = manager.as(Arel.sql('foo'))
          assert_kind_of Arel::Nodes::Grouping, as.left
          assert_equal manager.ast, as.left.expr
          assert_equal 'foo', as.right
        end

        it 'converts right to SqlLiteral if a string' do
          manager = Arel::SelectManager.new Table.engine
          as = manager.as('foo')
          assert_kind_of Arel::Nodes::SqlLiteral, as.right
        end

        it 'can make a subselect' do
          manager = Arel::SelectManager.new Table.engine
          manager.project Arel.star
          manager.from Arel.sql('zomg')
          as = manager.as(Arel.sql('foo'))

          manager = Arel::SelectManager.new Table.engine
          manager.project Arel.sql('name')
          manager.from as
          manager.to_sql.must_be_like "SELECT name FROM (SELECT * FROM zomg) foo"
        end
      end

      describe 'from' do
        it 'ignores strings when table of same name exists' do
          table   = Table.new :users
          manager = Arel::SelectManager.new Table.engine

          manager.from table
          manager.from 'users'
          manager.project table['id']
          manager.to_sql.must_be_like 'SELECT "users"."id" FROM users'
        end

        it 'should support any ast' do
          table   = Table.new :users
          manager1 = Arel::SelectManager.new Table.engine

          manager2 = Arel::SelectManager.new Table.engine
          manager2.project(Arel.sql('*'))
          manager2.from table

          manager1.project Arel.sql('lol')
          as = manager2.as Arel.sql('omg')
          manager1.from(as)

          manager1.to_sql.must_be_like %{
            SELECT lol FROM (SELECT * FROM "users") omg
          }
        end
      end

      describe 'having' do
        it 'converts strings to SQLLiterals' do
          table   = Table.new :users
          mgr = table.from table
          mgr.having 'foo'
          mgr.to_sql.must_be_like %{ SELECT FROM "users" HAVING foo }
        end

        it 'can have multiple items specified separately' do
          table = Table.new :users
          mgr = table.from table
          mgr.having 'foo'
          mgr.having 'bar'
          mgr.to_sql.must_be_like %{ SELECT FROM "users" HAVING foo AND bar }
        end

        it 'can have multiple items specified together' do
          table = Table.new :users
          mgr = table.from table
          mgr.having 'foo', 'bar'
          mgr.to_sql.must_be_like %{ SELECT FROM "users" HAVING foo AND bar }
        end
      end

      describe 'on' do
        it 'converts to sqlliterals' do
          table = Table.new :users
          right = table.alias
          mgr   = table.from table
          mgr.join(right).on("omg")
          mgr.to_sql.must_be_like %{ SELECT  FROM "users" INNER JOIN "users" "users_2" ON omg }
        end

        it 'converts to sqlliterals' do
          table = Table.new :users
          right = table.alias
          mgr   = table.from table
          mgr.join(right).on("omg", "123")
          mgr.to_sql.must_be_like %{ SELECT  FROM "users" INNER JOIN "users" "users_2" ON omg AND 123 }
        end
      end
    end

    describe 'clone' do
      it 'creates new cores' do
        table   = Table.new :users, :engine => Table.engine, :as => 'foo'
        mgr = table.from table
        m2 = mgr.clone
        m2.project "foo"
        mgr.to_sql.wont_equal m2.to_sql
      end

      it 'makes updates to the correct copy' do
        table   = Table.new :users, :engine => Table.engine, :as => 'foo'
        mgr = table.from table
        m2 = mgr.clone
        m3 = m2.clone
        m2.project "foo"
        mgr.to_sql.wont_equal m2.to_sql
        m3.to_sql.must_equal mgr.to_sql
      end
    end

    describe 'initialize' do
      it 'uses alias in sql' do
        table   = Table.new :users, :engine => Table.engine, :as => 'foo'
        mgr = table.from table
        mgr.skip 10
        mgr.to_sql.must_be_like %{ SELECT FROM "users" "foo" OFFSET 10 }
      end
    end

    describe 'skip' do
      it 'should add an offset' do
        table   = Table.new :users
        mgr = table.from table
        mgr.skip 10
        mgr.to_sql.must_be_like %{ SELECT FROM "users" OFFSET 10 }
      end

      it 'should chain' do
        table   = Table.new :users
        mgr = table.from table
        mgr.skip(10).to_sql.must_be_like %{ SELECT FROM "users" OFFSET 10 }
      end
    end

    describe 'offset' do
      it 'should add an offset' do
        table   = Table.new :users
        mgr = table.from table
        mgr.offset = 10
        mgr.to_sql.must_be_like %{ SELECT FROM "users" OFFSET 10 }
      end

      it 'should remove an offset' do
        table   = Table.new :users
        mgr = table.from table
        mgr.offset = 10
        mgr.to_sql.must_be_like %{ SELECT FROM "users" OFFSET 10 }

        mgr.offset = nil
        mgr.to_sql.must_be_like %{ SELECT FROM "users" }
      end

      it 'should return the offset' do
        table   = Table.new :users
        mgr = table.from table
        mgr.offset = 10
        assert_equal 10, mgr.offset
      end
    end

    describe 'exists' do
      it 'should create an exists clause' do
        table = Table.new(:users)
        manager = Arel::SelectManager.new Table.engine, table
        manager.project SqlLiteral.new '*'
        m2 = Arel::SelectManager.new(manager.engine)
        m2.project manager.exists
        m2.to_sql.must_be_like %{ SELECT EXISTS (#{manager.to_sql}) }
      end

      it 'can be aliased' do
        table = Table.new(:users)
        manager = Arel::SelectManager.new Table.engine, table
        manager.project SqlLiteral.new '*'
        m2 = Arel::SelectManager.new(manager.engine)
        m2.project manager.exists.as('foo')
        m2.to_sql.must_be_like %{ SELECT EXISTS (#{manager.to_sql}) AS foo }
      end
    end

    describe 'union' do
      before do
        table = Table.new :users
        @m1 = Arel::SelectManager.new Table.engine, table
        @m1.project Arel.star
        @m1.where(table[:age].lt(18))

        @m2 = Arel::SelectManager.new Table.engine, table
        @m2.project Arel.star
        @m2.where(table[:age].gt(99))


      end

      it 'should union two managers' do
        # FIXME should this union "managers" or "statements" ?
        # FIXME this probably shouldn't return a node
        node = @m1.union @m2

        # maybe FIXME: decide when wrapper parens are needed
        node.to_sql.must_be_like %{
          ( SELECT * FROM "users"  WHERE "users"."age" < 18 UNION SELECT * FROM "users"  WHERE "users"."age" > 99 )
        }
      end

      it 'should union all' do
        node = @m1.union :all, @m2

        node.to_sql.must_be_like %{
          ( SELECT * FROM "users"  WHERE "users"."age" < 18 UNION ALL SELECT * FROM "users"  WHERE "users"."age" > 99 )
        }
      end

    end

    describe 'intersect' do
      before do
        table = Table.new :users
        @m1 = Arel::SelectManager.new Table.engine, table
        @m1.project Arel.star
        @m1.where(table[:age].gt(18))

        @m2 = Arel::SelectManager.new Table.engine, table
        @m2.project Arel.star
        @m2.where(table[:age].lt(99))


      end

      it 'should interect two managers' do
        # FIXME should this intersect "managers" or "statements" ?
        # FIXME this probably shouldn't return a node
        node = @m1.intersect @m2

        # maybe FIXME: decide when wrapper parens are needed
        node.to_sql.must_be_like %{
          ( SELECT * FROM "users"  WHERE "users"."age" > 18 INTERSECT SELECT * FROM "users"  WHERE "users"."age" < 99 )
        }
      end

    end

    describe 'except' do
      before do
        table = Table.new :users
        @m1 = Arel::SelectManager.new Table.engine, table
        @m1.project Arel.star
        @m1.where(table[:age].in(18..60))

        @m2 = Arel::SelectManager.new Table.engine, table
        @m2.project Arel.star
        @m2.where(table[:age].in(40..99))


      end

      it 'should except two managers' do
        # FIXME should this except "managers" or "statements" ?
        # FIXME this probably shouldn't return a node
        node = @m1.except @m2

        # maybe FIXME: decide when wrapper parens are needed
        node.to_sql.must_be_like %{
          ( SELECT * FROM "users"  WHERE "users"."age" BETWEEN 18 AND 60 EXCEPT SELECT * FROM "users"  WHERE "users"."age" BETWEEN 40 AND 99 )
        }
      end

    end

    describe 'with' do

      it "should support WITH RECURSIVE" do
        comments           = Table.new(:comments)
        comments_id        = comments[:id]
        comments_parent_id = comments[:parent_id]

        replies            = Table.new(:replies)
        replies_id         = replies[:id]

        recursive_term = Arel::SelectManager.new Table.engine
        recursive_term.from(comments).project(comments_id, comments_parent_id).where(comments_id.eq 42)

        non_recursive_term = Arel::SelectManager.new Table.engine
        non_recursive_term.from(comments).project(comments_id, comments_parent_id).join(replies).on(comments_parent_id.eq replies_id)

        union = recursive_term.union(non_recursive_term)

        as_statement = Arel::Nodes::As.new replies, union

        manager = Arel::SelectManager.new Table.engine
        manager.with(:recursive, as_statement).from(replies).project(Arel.star)

        sql = manager.to_sql
        sql.must_be_like %{
          WITH RECURSIVE "replies" AS (
              SELECT "comments"."id", "comments"."parent_id" FROM "comments" WHERE "comments"."id" = 42
            UNION
              SELECT "comments"."id", "comments"."parent_id" FROM "comments" INNER JOIN "replies" ON "comments"."parent_id" = "replies"."id"
          )
          SELECT * FROM "replies"
        }
      end
    end

    describe 'ast' do
      it 'should return the ast' do
        table   = Table.new :users
        mgr = table.from table
        ast = mgr.ast
        mgr.visitor.accept(ast).must_equal mgr.to_sql
      end
      it 'should allow orders to work when the ast is grepped' do
        table   = Table.new :users
        mgr = table.from table
        mgr.project Arel.sql '*'
        mgr.from table
        mgr.orders << Arel::Nodes::Ascending.new(Arel.sql('foo'))
        mgr.ast.grep(Arel::Nodes::OuterJoin)
        mgr.to_sql.must_be_like %{ SELECT * FROM "users" ORDER BY foo ASC }
      end
    end

    describe 'taken' do
      it 'should return limit' do
        manager = Arel::SelectManager.new Table.engine
        manager.take 10
        manager.taken.must_equal 10
      end
    end

    describe 'lock' do
      # This should fail on other databases
      it 'adds a lock node' do
        table   = Table.new :users
        mgr = table.from table
        mgr.lock.to_sql.must_be_like %{ SELECT FROM "users" FOR UPDATE }
      end
    end

    describe 'orders' do
      it 'returns order clauses' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        order = table[:id]
        manager.order table[:id]
        manager.orders.must_equal [order]
      end
    end

    describe 'order' do
      it 'generates order clauses' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project SqlLiteral.new '*'
        manager.from table
        manager.order table[:id]
        manager.to_sql.must_be_like %{
          SELECT * FROM "users" ORDER BY "users"."id"
        }
      end

      # FIXME: I would like to deprecate this
      it 'takes *args' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project SqlLiteral.new '*'
        manager.from table
        manager.order table[:id], table[:name]
        manager.to_sql.must_be_like %{
          SELECT * FROM "users" ORDER BY "users"."id", "users"."name"
        }
      end

      it 'chains' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.order(table[:id]).must_equal manager
      end

      it 'has order attributes' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project SqlLiteral.new '*'
        manager.from table
        manager.order table[:id].desc
        manager.to_sql.must_be_like %{
          SELECT * FROM "users" ORDER BY "users"."id" DESC
        }
      end

      it 'has order attributes for expressions' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project SqlLiteral.new '*'
        manager.from table
        manager.order table[:id].count.desc
        manager.to_sql.must_be_like %{
          SELECT * FROM "users" ORDER BY COUNT("users"."id") DESC
        }
      end

    end

    describe 'on' do
      it 'takes two params' do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new Table.engine

        manager.from left
        manager.join(right).on(predicate, predicate)
        manager.to_sql.must_be_like %{
           SELECT FROM "users"
             INNER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id" AND
               "users"."id" = "users_2"."id"
        }
      end

      it 'takes three params' do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new Table.engine

        manager.from left
        manager.join(right).on(
          predicate,
          predicate,
          left[:name].eq(right[:name])
        )
        manager.to_sql.must_be_like %{
           SELECT FROM "users"
             INNER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id" AND
               "users"."id" = "users_2"."id" AND
               "users"."name" = "users_2"."name"
        }
      end
    end

    it 'should hand back froms' do
      relation = Arel::SelectManager.new Table.engine
      assert_equal [], relation.froms
    end

    it 'should create and nodes' do
      relation = Arel::SelectManager.new Table.engine
      children = ['foo', 'bar', 'baz']
      clause = relation.create_and children
      assert_kind_of Arel::Nodes::And, clause
      assert_equal children, clause.children
    end

    it 'should create insert managers' do
      relation = Arel::SelectManager.new Table.engine
      insert = relation.create_insert
      assert_kind_of Arel::InsertManager, insert
    end

    it 'should create join nodes' do
      relation = Arel::SelectManager.new Table.engine
      join = relation.create_join 'foo', 'bar'
      assert_kind_of Arel::Nodes::InnerJoin, join
      assert_equal 'foo', join.left
      assert_equal 'bar', join.right
    end

    it 'should create join nodes with a klass' do
      relation = Arel::SelectManager.new Table.engine
      join = relation.create_join 'foo', 'bar', Arel::Nodes::OuterJoin
      assert_kind_of Arel::Nodes::OuterJoin, join
      assert_equal 'foo', join.left
      assert_equal 'bar', join.right
    end

    describe 'join' do
      it 'responds to join' do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new Table.engine

        manager.from left
        manager.join(right).on(predicate)
        manager.to_sql.must_be_like %{
           SELECT FROM "users"
             INNER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end

      it 'takes a class' do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])
        manager   = Arel::SelectManager.new Table.engine

        manager.from left
        manager.join(right, Nodes::OuterJoin).on(predicate)
        manager.to_sql.must_be_like %{
           SELECT FROM "users"
             LEFT OUTER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end

      it 'noops on nil' do
        manager   = Arel::SelectManager.new Table.engine
        manager.join(nil).must_equal manager
      end
    end

    describe 'joins' do
      it 'returns join sql' do
        table   = Table.new :users
        aliaz   = table.alias
        manager = Arel::SelectManager.new Table.engine
        manager.from Nodes::InnerJoin.new(aliaz, table[:id].eq(aliaz[:id]))
        manager.join_sql.must_be_like %{
          INNER JOIN "users" "users_2" "users"."id" = "users_2"."id"
        }
      end

      it 'returns outer join sql' do
        table   = Table.new :users
        aliaz   = table.alias
        manager = Arel::SelectManager.new Table.engine
        manager.from Nodes::OuterJoin.new(aliaz, table[:id].eq(aliaz[:id]))
        manager.join_sql.must_be_like %{
          LEFT OUTER JOIN "users" "users_2" "users"."id" = "users_2"."id"
        }
      end

      it 'can have a non-table alias as relation name' do
        users    = Table.new :users
        comments = Table.new :comments

        counts = comments.from(comments).
          group(comments[:user_id]).
          project(
            comments[:user_id].as("user_id"),
            comments[:user_id].count.as("count")
          ).as("counts")

        joins = users.join(counts).on(counts[:user_id].eq(10))
        joins.to_sql.must_be_like  %{
          SELECT FROM "users" INNER JOIN (SELECT "comments"."user_id" AS user_id, COUNT("comments"."user_id") AS count FROM "comments" GROUP BY "comments"."user_id") counts ON counts."user_id" = 10
        }
      end

      it 'returns string join sql' do
        manager = Arel::SelectManager.new Table.engine
        manager.from Nodes::StringJoin.new('hello')
        manager.join_sql.must_be_like %{ 'hello' }
      end

      it 'returns nil join sql' do
        manager = Arel::SelectManager.new Table.engine
        manager.join_sql.must_be_nil
      end
    end

    describe 'order_clauses' do
      it 'returns order clauses as a list' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.order table[:id]
        manager.order_clauses.first.must_be_like %{ "users"."id" }
      end
    end

    describe 'group' do
      it 'takes an attribute' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.group table[:id]
        manager.to_sql.must_be_like %{
          SELECT FROM "users" GROUP BY "users"."id"
        }
      end

      it 'chains' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.group(table[:id]).must_equal manager
      end

      it 'takes multiple args' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.group table[:id], table[:name]
        manager.to_sql.must_be_like %{
          SELECT FROM "users" GROUP BY "users"."id", "users"."name"
        }
      end

      # FIXME: backwards compat
      it 'makes strings literals' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.group 'foo'
        manager.to_sql.must_be_like %{ SELECT FROM "users" GROUP BY foo }
      end
    end

    describe 'window definition' do
      it 'can be empty' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window')
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS ()
        }
      end

      it 'takes an order' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').order(table['foo'].asc)
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ORDER BY "users"."foo" ASC)
        }
      end

      it 'takes a rows frame, unbounded preceding' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').rows(Arel::Nodes::Preceding.new)
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS UNBOUNDED PRECEDING)
        }
      end

      it 'takes a rows frame, bounded preceding' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').rows(Arel::Nodes::Preceding.new(5))
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS 5 PRECEDING)
        }
      end

      it 'takes a rows frame, unbounded following' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').rows(Arel::Nodes::Following.new)
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS UNBOUNDED FOLLOWING)
        }
      end

      it 'takes a rows frame, bounded following' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').rows(Arel::Nodes::Following.new(5))
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS 5 FOLLOWING)
        }
      end

      it 'takes a rows frame, current row' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').rows(Arel::Nodes::CurrentRow.new)
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS CURRENT ROW)
        }
      end

      it 'takes a rows frame, between two delimiters' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        window = manager.window('a_window')
        window.frame(
          Arel::Nodes::Between.new(
            window.rows,
            Nodes::And.new([
              Arel::Nodes::Preceding.new,
              Arel::Nodes::CurrentRow.new
            ])))
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        }
      end

      it 'takes a range frame, unbounded preceding' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').range(Arel::Nodes::Preceding.new)
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE UNBOUNDED PRECEDING)
        }
      end

      it 'takes a range frame, bounded preceding' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').range(Arel::Nodes::Preceding.new(5))
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE 5 PRECEDING)
        }
      end

      it 'takes a range frame, unbounded following' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').range(Arel::Nodes::Following.new)
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE UNBOUNDED FOLLOWING)
        }
      end

      it 'takes a range frame, bounded following' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').range(Arel::Nodes::Following.new(5))
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE 5 FOLLOWING)
        }
      end

      it 'takes a range frame, current row' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.window('a_window').range(Arel::Nodes::CurrentRow.new)
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE CURRENT ROW)
        }
      end

      it 'takes a range frame, between two delimiters' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        window = manager.window('a_window')
        window.frame(
          Arel::Nodes::Between.new(
            window.range,
            Nodes::And.new([
              Arel::Nodes::Preceding.new,
              Arel::Nodes::CurrentRow.new
            ])))
        manager.to_sql.must_be_like %{
          SELECT FROM "users" WINDOW "a_window" AS (RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        }
      end
    end

    describe 'delete' do
      it "copies from" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        stmt = manager.compile_delete

        stmt.to_sql.must_be_like %{ DELETE FROM "users" }
      end

      it "copies where" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.where table[:id].eq 10
        stmt = manager.compile_delete

        stmt.to_sql.must_be_like %{
          DELETE FROM "users" WHERE "users"."id" = 10
        }
      end
    end

    describe 'where_sql' do
      it 'gives me back the where sql' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.where table[:id].eq 10
        manager.where_sql.must_be_like %{ WHERE "users"."id" = 10 }
      end

      it 'returns nil when there are no wheres' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.where_sql.must_be_nil
      end
    end

    describe 'update' do
      it 'copies limits' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.take 1
        stmt = manager.compile_update(SqlLiteral.new('foo = bar'), Arel::Attributes::Attribute.new(table, 'id'))
        stmt.key = table['id']

        stmt.to_sql.must_be_like %{
          UPDATE "users" SET foo = bar
          WHERE "users"."id" IN (SELECT "users"."id" FROM "users" LIMIT 1)
        }
      end

      it 'copies order' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        manager.order :foo
        stmt = manager.compile_update(SqlLiteral.new('foo = bar'), Arel::Attributes::Attribute.new(table, 'id'))
        stmt.key = table['id']

        stmt.to_sql.must_be_like %{
          UPDATE "users" SET foo = bar
          WHERE "users"."id" IN (SELECT "users"."id" FROM "users" ORDER BY foo)
        }
      end

      it 'takes a string' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        stmt = manager.compile_update(SqlLiteral.new('foo = bar'), Arel::Attributes::Attribute.new(table, 'id'))

        stmt.to_sql.must_be_like %{ UPDATE "users" SET foo = bar }
      end

      it 'copies where clauses' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.where table[:id].eq 10
        manager.from table
        stmt = manager.compile_update({table[:id] => 1}, Arel::Attributes::Attribute.new(table, 'id'))

        stmt.to_sql.must_be_like %{
          UPDATE "users" SET "id" = 1 WHERE "users"."id" = 10
        }
      end

      it 'copies where clauses when nesting is triggered' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.where table[:foo].eq 10
        manager.take 42
        manager.from table
        stmt = manager.compile_update({table[:id] => 1}, Arel::Attributes::Attribute.new(table, 'id'))

        stmt.to_sql.must_be_like %{
          UPDATE "users" SET "id" = 1 WHERE "users"."id" IN (SELECT "users"."id" FROM "users" WHERE "users"."foo" = 10 LIMIT 42)
        }
      end

      it 'executes an update statement' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from table
        stmt = manager.compile_update({table[:id] => 1}, Arel::Attributes::Attribute.new(table, 'id'))

        stmt.to_sql.must_be_like %{
          UPDATE "users" SET "id" = 1
        }
      end
    end

    describe 'project' do
      it 'takes multiple args' do
        manager = Arel::SelectManager.new Table.engine
        manager.project Nodes::SqlLiteral.new('foo'),
          Nodes::SqlLiteral.new('bar')
        manager.to_sql.must_be_like %{ SELECT foo, bar }
      end

      it 'takes strings' do
        manager = Arel::SelectManager.new Table.engine
        manager.project '*'
        manager.to_sql.must_be_like %{ SELECT * }
      end

      it "takes sql literals" do
        manager = Arel::SelectManager.new Table.engine
        manager.project Nodes::SqlLiteral.new '*'
        manager.to_sql.must_be_like %{ SELECT * }
      end
    end

    describe 'projections' do
      it 'reads projections' do
        manager = Arel::SelectManager.new Table.engine
        manager.project Arel.sql('foo'), Arel.sql('bar')
        manager.projections.must_equal [Arel.sql('foo'), Arel.sql('bar')]
      end
    end

    describe 'projections=' do
      it 'overwrites projections' do
        manager = Arel::SelectManager.new Table.engine
        manager.project Arel.sql('foo')
        manager.projections = [Arel.sql('bar')]
        manager.to_sql.must_be_like %{ SELECT bar }
      end
    end

    describe 'take' do
      it "knows take" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from(table).project(table['id'])
        manager.where(table['id'].eq(1))
        manager.take 1

        manager.to_sql.must_be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
          LIMIT 1
        }
      end

      it "chains" do
        manager = Arel::SelectManager.new Table.engine
        manager.take(1).must_equal manager
      end

      it 'removes LIMIT when nil is passed' do
        manager = Arel::SelectManager.new Table.engine
        manager.limit = 10
        assert_match('LIMIT', manager.to_sql)

        manager.limit = nil
        refute_match('LIMIT', manager.to_sql)
      end
    end

    describe 'where' do
      it "knows where" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from(table).project(table['id'])
        manager.where(table['id'].eq(1))
        manager.to_sql.must_be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
        }
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from(table)
        manager.project(table['id']).where(table['id'].eq 1).must_equal manager
      end
    end

    describe "join" do
      it "joins itself" do
        left      = Table.new :users
        right     = left.alias
        predicate = left[:id].eq(right[:id])

        mgr = left.join(right)
        mgr.project Nodes::SqlLiteral.new('*')
        mgr.on(predicate).must_equal mgr

        mgr.to_sql.must_be_like %{
           SELECT * FROM "users"
             INNER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
        }
      end
    end

    describe 'from' do
      it "makes sql" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine

        manager.from table
        manager.project table['id']
        manager.to_sql.must_be_like 'SELECT "users"."id" FROM "users"'
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from(table).project(table['id']).must_equal manager
        manager.to_sql.must_be_like 'SELECT "users"."id" FROM "users"'
      end
    end

    describe 'source' do
      it 'returns the join source of the select core' do
        manager = Arel::SelectManager.new Table.engine
        manager.source.must_equal manager.ast.cores.last.source
      end
    end

    describe 'distinct' do
      it 'sets the quantifier' do
        manager = Arel::SelectManager.new Table.engine

        manager.distinct
        manager.ast.cores.last.set_quantifier.class.must_equal Arel::Nodes::Distinct

        manager.distinct(false)
        manager.ast.cores.last.set_quantifier.must_equal nil
      end
    end
  end
end
