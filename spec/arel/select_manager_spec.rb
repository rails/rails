require 'spec_helper'

module Arel
  class EngineProxy
    attr_reader :executed

    def initialize engine
      @engine = engine
      @executed = []
    end

    def connection
      self
    end

    def quote_table_name thing; @engine.connection.quote_table_name thing end
    def quote_column_name thing; @engine.connection.quote_column_name thing end
    def quote thing, column; @engine.connection.quote thing, column end

    def execute sql
      @executed << sql
    end
  end

  describe 'select manager' do
    describe 'update' do
      it 'copies where clauses' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.where table[:id].eq 10
        manager.from table
        manager.update(table[:id] => 1)

        engine.executed.last.should be_like %{
          UPDATE "users" SET "id" = 1 WHERE "users"."id" = 10
        }
      end

      it 'executes an update statement' do
        engine  = EngineProxy.new Table.engine
        table   = Table.new :users
        manager = Arel::SelectManager.new engine
        manager.from table
        manager.update(table[:id] => 1)

        engine.executed.last.should be_like %{
          UPDATE "users" SET "id" = 1
        }
      end
    end

    describe 'project' do
      it 'takes strings' do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project '*'
        manager.to_sql.should be_like %{
          SELECT *
        }
      end

      it "takes sql literals" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.project Nodes::SqlLiteral.new '*'
        manager.to_sql.should be_like %{
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

        manager.to_sql.should be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
          LIMIT 1
        }
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.take(1).should == manager
      end
    end

    describe 'where' do
      it "knows where" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from(table).project(table['id'])
        manager.where(table['id'].eq(1))
        manager.to_sql.should be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
        }
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        manager.from(table)
        manager.project(table['id']).where(table['id'].eq 1).should == manager
      end
    end

    describe 'from' do
      it "makes sql" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine

        manager.from table
        manager.project table['id']
        manager.to_sql.should be_like 'SELECT "users"."id" FROM "users"'
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::SelectManager.new Table.engine
        check manager.from(table).project(table['id']).should == manager
        manager.to_sql.should be_like 'SELECT "users"."id" FROM "users"'
      end
    end
  end
end
