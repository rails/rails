require 'helper'

module Arel
  describe Table do
    before do
      @relation = Table.new(:users)
    end

    it 'should create join nodes' do
      join = @relation.create_string_join 'foo'
      assert_kind_of Arel::Nodes::StringJoin, join
      assert_equal 'foo', join.left
    end

    it 'should create join nodes' do
      join = @relation.create_join 'foo', 'bar'
      assert_kind_of Arel::Nodes::InnerJoin, join
      assert_equal 'foo', join.left
      assert_equal 'bar', join.right
    end

    it 'should create join nodes with a klass' do
      join = @relation.create_join 'foo', 'bar', Arel::Nodes::OuterJoin
      assert_kind_of Arel::Nodes::OuterJoin, join
      assert_equal 'foo', join.left
      assert_equal 'bar', join.right
    end

    it 'should return an insert manager' do
      im = @relation.compile_insert 'VALUES(NULL)'
      assert_kind_of Arel::InsertManager, im
      assert_equal 'INSERT INTO NULL VALUES(NULL)', im.to_sql
    end

    it 'should return IM from insert_manager' do
      im = @relation.insert_manager
      assert_kind_of Arel::InsertManager, im
      assert_equal im.engine, @relation.engine
    end

    describe 'skip' do
      it 'should add an offset' do
        sm = @relation.skip 2
        sm.to_sql.must_be_like "SELECT FROM \"users\" OFFSET 2"
      end
    end

    describe 'select_manager' do
      it 'should return an empty select manager' do
        sm = @relation.select_manager
        sm.to_sql.must_be_like 'SELECT'
      end
    end

    describe 'having' do
      it 'adds a having clause' do
        mgr = @relation.having @relation[:id].eq(10)
        mgr.to_sql.must_be_like %{
         SELECT FROM "users" HAVING "users"."id" = 10
        }
      end
    end

    describe 'backwards compat' do
      describe 'join' do
        it 'noops on nil' do
          mgr = @relation.join nil

          mgr.to_sql.must_be_like %{ SELECT FROM "users" }
        end

        it 'takes a second argument for join type' do
          right     = @relation.alias
          predicate = @relation[:id].eq(right[:id])
          mgr = @relation.join(right, Nodes::OuterJoin).on(predicate)

          mgr.to_sql.must_be_like %{
           SELECT FROM "users"
             LEFT OUTER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
          }
        end
      end
    end

    describe 'group' do
      it 'should create a group' do
        manager = @relation.group @relation[:id]
        manager.to_sql.must_be_like %{
          SELECT FROM "users" GROUP BY "users"."id"
        }
      end
    end

    describe 'alias' do
      it 'should create a node that proxies to a table' do
        @relation.aliases.must_equal []

        node = @relation.alias
        @relation.aliases.must_equal [node]
        node.name.must_equal 'users_2'
        node[:id].relation.must_equal node
      end
    end

    describe 'new' do
      it 'should accept an engine' do
        rel = Table.new :users, 'foo'
        rel.engine.must_equal 'foo'
      end

      it 'should accept a hash' do
        rel = Table.new :users, :engine => 'foo'
        rel.engine.must_equal 'foo'
      end

      it 'ignores as if it equals name' do
        rel = Table.new :users, :as => 'users'
        rel.table_alias.must_be_nil
      end
    end

    describe 'order' do
      it "should take an order" do
        manager = @relation.order "foo"
        manager.to_sql.must_be_like %{ SELECT FROM "users" ORDER BY foo }
      end
    end

    describe 'take' do
      it "should add a limit" do
        manager = @relation.take 1
        manager.project SqlLiteral.new '*'
        manager.to_sql.must_be_like %{ SELECT * FROM "users" LIMIT 1 }
      end
    end

    describe 'project' do
      it 'can project' do
        manager = @relation.project SqlLiteral.new '*'
        manager.to_sql.must_be_like %{ SELECT * FROM "users" }
      end

      it 'takes multiple parameters' do
        manager = @relation.project SqlLiteral.new('*'), SqlLiteral.new('*')
        manager.to_sql.must_be_like %{ SELECT *, * FROM "users" }
      end
    end

    describe 'where' do
      it "returns a tree manager" do
        manager = @relation.where @relation[:id].eq 1
        manager.project @relation[:id]
        manager.must_be_kind_of TreeManager
        manager.to_sql.must_be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
        }
      end
    end

    it "should have a name" do
      @relation.name.must_equal 'users'
    end

    it "should have a table name" do
      @relation.table_name.must_equal 'users'
    end

    it "should have an engine" do
      @relation.engine.must_equal Table.engine
    end

    describe '[]' do
      describe 'when given a Symbol' do
        it "manufactures an attribute if the symbol names an attribute within the relation" do
          column = @relation[:id]
          column.name.must_equal :id
        end
      end
    end
  end
end
