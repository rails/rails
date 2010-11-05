require 'helper'

module Arel
  class EngineProxy
    attr_reader :executed
    attr_reader :connection_pool
    attr_reader :spec
    attr_reader :config

    def initialize engine
      @engine = engine
      @executed = []
      @connection_pool = self
      @spec = self
      @config = { :adapter => 'sqlite3' }
    end

    def with_connection
      yield self
    end

    def connection
      self
    end

    def quote_table_name thing; @engine.connection.quote_table_name thing end
    def quote_column_name thing; @engine.connection.quote_column_name thing end
    def quote thing, column; @engine.connection.quote thing, column end

    def execute sql, name = nil, *args
      @executed << sql
    end
    alias :update :execute
    alias :delete :execute
    alias :insert :execute
  end

  describe 'select manager' do
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

      describe 'from' do
        it 'ignores strings when table of same name exists' do
          table   = Table.new :users
          manager = Arel::SelectManager.new Table.engine

          manager.from table
          manager.from 'users'
          manager.project table['id']
          manager.to_sql.must_be_like 'SELECT "users"."id" FROM users'
        end
      end

      describe '#having' do
        it 'converts strings to SQLLiterals' do
          table   = Table.new :users
          mgr = table.from table
          mgr.having 'foo'
          mgr.to_sql.must_be_like %{ SELECT FROM "users" HAVING foo }
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

    describe 'ast' do
      it 'should return the ast' do
        table   = Table.new :users
        mgr = table.from table
        ast = mgr.ast
        mgr.visitor.accept(ast).must_equal mgr.to_sql
      end
    end

    describe 'taken' do
      it 'should return limit' do
        manager = Arel::SelectManager.new Table.engine
        manager.take 10
        manager.taken.must_equal 10
      end
    end

    describe 'insert' do
      it 'uses the select FROM' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.insert 'VALUES(NULL)'

        engine.executed.last.must_be_like %{
          INSERT INTO "users" VALUES(NULL)
        }
      end
    end

    describe 'lock' do
      # This should fail on other databases
      it 'adds a lock node' do
        table   = Table.new :users
        mgr = table.from table
        mgr.lock.to_sql.must_be_like %{ SELECT FROM "users" }
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
        manager.from Nodes::InnerJoin.new(table, aliaz, table[:id].eq(aliaz[:id]))
        manager.join_sql.must_be_like %{
          INNER JOIN "users" "users_2" "users"."id" = "users_2"."id"
        }
        manager.joins(manager).must_equal manager.join_sql
      end

      it 'returns outer join sql' do
        table   = Table.new :users
        aliaz   = table.alias
        manager = Arel::SelectManager.new Table.engine
        manager.from Nodes::OuterJoin.new(table, aliaz, table[:id].eq(aliaz[:id]))
        manager.join_sql.must_be_like %{
          LEFT OUTER JOIN "users" "users_2" "users"."id" = "users_2"."id"
        }
        manager.joins(manager).must_equal manager.join_sql
      end

      it 'returns string join sql' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from Nodes::StringJoin.new(table, 'hello')
        manager.join_sql.must_be_like %{ 'hello' }
        manager.joins(manager).must_equal manager.join_sql
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

    describe 'delete' do
      it "copies from" do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.delete

        engine.executed.last.must_be_like %{ DELETE FROM "users" }
      end

      it "copies where" do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.where table[:id].eq 10
        manager.delete

        engine.executed.last.must_be_like %{
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
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.take 1
        manager.update(SqlLiteral.new('foo = bar'))

        engine.executed.last.must_be_like %{
          UPDATE "users" SET foo = bar
          WHERE "users"."id" IN (SELECT "users"."id" FROM "users" LIMIT 1)
        }
      end

      it 'copies order' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.order :foo
        manager.update(SqlLiteral.new('foo = bar'))

        engine.executed.last.must_be_like %{
          UPDATE "users" SET foo = bar
          WHERE "users"."id" IN (SELECT "users"."id" FROM "users" ORDER BY foo)
        }
      end

      it 'takes a string' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.update(SqlLiteral.new('foo = bar'))

        engine.executed.last.must_be_like %{ UPDATE "users" SET foo = bar }
      end

      it 'copies where clauses' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.where table[:id].eq 10
        manager.from table
        manager.update(table[:id] => 1)

        engine.executed.last.must_be_like %{
          UPDATE "users" SET "id" = 1 WHERE "users"."id" = 10
        }
      end

      it 'executes an update statement' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.update(table[:id] => 1)

        engine.executed.last.must_be_like %{
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
        manager.project Nodes::SqlLiteral.new('*')
        manager.to_sql.must_be_like %{ SELECT * }
      end

      it "takes sql literals" do
        manager = Arel::SelectManager.new Table.engine
        manager.project Nodes::SqlLiteral.new '*'
        manager.to_sql.must_be_like %{
          SELECT *
        }
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
  end
end
