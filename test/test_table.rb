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
      join = @relation.create_join 'foo', 'bar', Arel::Nodes::FullOuterJoin
      assert_kind_of Arel::Nodes::FullOuterJoin, join
      assert_equal 'foo', join.left
      assert_equal 'bar', join.right
    end

    it 'should create join nodes with a klass' do
      join = @relation.create_join 'foo', 'bar', Arel::Nodes::OuterJoin
      assert_kind_of Arel::Nodes::OuterJoin, join
      assert_equal 'foo', join.left
      assert_equal 'bar', join.right
    end

    it 'should create join nodes with a klass' do
      join = @relation.create_join 'foo', 'bar', Arel::Nodes::RightOuterJoin
      assert_kind_of Arel::Nodes::RightOuterJoin, join
      assert_equal 'foo', join.left
      assert_equal 'bar', join.right
    end

    it 'should return an insert manager' do
      im = @relation.compile_insert 'VALUES(NULL)'
      assert_kind_of Arel::InsertManager, im
      im.into Table.new(:users)
      assert_equal "INSERT INTO \"users\" VALUES(NULL)", im.to_sql
    end

    describe 'skip' do
      it 'should add an offset' do
        sm = @relation.skip 2
        sm.to_sql.must_be_like "SELECT FROM \"users\" OFFSET 2"
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

      describe 'join' do
        it 'creates an outer join' do
          right     = @relation.alias
          predicate = @relation[:id].eq(right[:id])
          mgr = @relation.outer_join(right).on(predicate)

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
        node = @relation.alias
        node.name.must_equal 'users_2'
        node[:id].relation.must_equal node
      end
    end

    describe 'new' do
      it 'should accept a hash' do
        rel = Table.new :users, :as => 'foo'
        rel.table_alias.must_equal 'foo'
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
        manager.project Nodes::SqlLiteral.new '*'
        manager.to_sql.must_be_like %{ SELECT * FROM "users" LIMIT 1 }
      end
    end

    describe 'project' do
      it 'can project' do
        manager = @relation.project Nodes::SqlLiteral.new '*'
        manager.to_sql.must_be_like %{ SELECT * FROM "users" }
      end

      it 'takes multiple parameters' do
        manager = @relation.project Nodes::SqlLiteral.new('*'), Nodes::SqlLiteral.new('*')
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

    describe '[]' do
      describe 'when given a Symbol' do
        it "manufactures an attribute if the symbol names an attribute within the relation" do
          column = @relation[:id]
          column.name.must_equal :id
        end
      end
    end

    describe 'equality' do
      it 'is equal with equal ivars' do
        relation1 = Table.new(:users)
        relation1.table_alias = 'zomg'
        relation2 = Table.new(:users)
        relation2.table_alias = 'zomg'
        array = [relation1, relation2]
        assert_equal 1, array.uniq.size
      end

      it 'is not equal with different ivars' do
        relation1 = Table.new(:users)
        relation1.table_alias = 'zomg'
        relation2 = Table.new(:users)
        relation2.table_alias = 'zomg2'
        array = [relation1, relation2]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
