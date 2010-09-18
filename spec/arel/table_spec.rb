require 'spec_helper'

module Arel
  describe Table do
    before do
      @relation = Table.new(:users)
    end

    describe 'primary_key' do
      it 'should return an attribute' do
        check @relation.primary_key.name.should == :id
      end
    end

    describe 'having' do
      it 'adds a having clause' do
        mgr = @relation.having @relation[:id].eq(10)
        mgr.to_sql.should be_like %{
         SELECT FROM "users" HAVING "users"."id" = 10
        }
      end
    end

    describe 'backwards compat' do
      describe 'joins' do
        it 'returns nil' do
          check @relation.joins(nil).should == nil
        end
      end

      describe 'join' do
        it 'noops on nil' do
          mgr = @relation.join nil

          mgr.to_sql.should be_like %{ SELECT FROM "users" }
        end

        it 'takes a second argument for join type' do
          right     = @relation.alias
          predicate = @relation[:id].eq(right[:id])
          mgr = @relation.join(right, Nodes::OuterJoin).on(predicate)

          mgr.to_sql.should be_like %{
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
        manager.to_sql.should be_like %{
          SELECT FROM "users" GROUP BY "users"."id"
        }
      end
    end

    describe 'alias' do
      it 'should create a node that proxies to a table' do
        check @relation.aliases.should == []

        node = @relation.alias
        check @relation.aliases.should == [node]
        check node.name.should == 'users_2'
        check node[:id].relation.should == node
        check node[:id].relation.should != node
      end
    end

    describe 'new' do
      it 'should accept an engine' do
        rel = Table.new :users, 'foo'
        check rel.engine.should == 'foo'
      end

      it 'should accept a hash' do
        rel = Table.new :users, :engine => 'foo'
        check rel.engine.should == 'foo'
      end
    end

    describe 'order' do
      it "should take an order" do
        manager = @relation.order "foo"
        manager.to_sql.should be_like %{ SELECT FROM "users" ORDER BY foo }
      end
    end

    describe 'take' do
      it "should add a limit" do
        manager = @relation.take 1
        manager.project SqlLiteral.new '*'
        manager.to_sql.should be_like %{ SELECT * FROM "users" LIMIT 1 }
      end
    end

    describe 'project' do
      it 'can project' do
        manager = @relation.project SqlLiteral.new '*'
        manager.to_sql.should be_like %{ SELECT * FROM "users" }
      end

      it 'takes multiple parameters' do
        manager = @relation.project SqlLiteral.new('*'), SqlLiteral.new('*')
        manager.to_sql.should be_like %{ SELECT *, * FROM "users" }
      end
    end

    describe 'where' do
      it "returns a tree manager" do
        manager = @relation.where @relation[:id].eq 1
        manager.project @relation[:id]
        manager.should be_kind_of TreeManager
        manager.to_sql.should be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
        }
      end
    end

    describe 'columns' do
      it 'returns a list of columns' do
        columns = @relation.columns
        check columns.length.should == 2
        columns.map { |x| x.name.to_s }.sort.should == %w{ name id }.sort
      end
    end

    it "should have a name" do
      @relation.name.should == :users
    end

    it "should have an engine" do
      @relation.engine.should == Table.engine
    end

    describe '[]' do
      describe 'when given a', Symbol do
        it "manufactures an attribute if the symbol names an attribute within the relation" do
          column = @relation[:id]
          check column.name.should == :id
          column.should be_kind_of Attributes::Integer
        end
      end

      describe 'when table does not exist' do
        it 'returns nil' do
          @relation[:foooo].should be_nil
        end
      end
    end
  end
end
