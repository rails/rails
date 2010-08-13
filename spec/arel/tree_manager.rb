require 'spec_helper'

module Arel
  describe 'tree manager' do
    describe 'take' do
      it "knows take" do
        table   = Table.new :users
        manager = Arel::TreeManager.new Table.engine
        manager.from(table).project(table['id'])
        manager.where(table['id'].eq(1))
        manager.take 1

        manager.to_sql.should == %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
          LIMIT 1
        }.gsub("\n", '').gsub(/(^\s*|\s*$)/, '').squeeze(' ')
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::TreeManager.new Table.engine
        manager.take(1).should == manager
      end
    end

    describe 'where' do
      it "knows where" do
        table   = Table.new :users
        manager = Arel::TreeManager.new Table.engine
        manager.from(table).project(table['id'])
        manager.where(table['id'].eq(1))
        manager.to_sql.should == %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
        }.gsub("\n", '').gsub(/(^\s*|\s*$)/, '').squeeze(' ')
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::TreeManager.new Table.engine
        manager.from(table)
        manager.project(table['id']).where(table['id'].eq 1).should == manager
      end
    end

    describe 'from' do
      it "makes sql" do
        table   = Table.new :users
        manager = Arel::TreeManager.new Table.engine

        manager.from table
        manager.project table['id']
        manager.to_sql.should == 'SELECT "users"."id" FROM "users"'
      end

      it "chains" do
        table   = Table.new :users
        manager = Arel::TreeManager.new Table.engine
        manager.from(table).project(table['id']).should == manager
        manager.to_sql.should == 'SELECT "users"."id" FROM "users"'
      end
    end
  end
end
