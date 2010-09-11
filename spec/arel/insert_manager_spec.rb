require 'spec_helper'

module Arel
  describe 'insert manager' do
    describe 'new' do
      it 'takes an engine' do
        Arel::InsertManager.new Table.engine
      end
    end

    describe 'insert' do
      it "inserts false" do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine
        manager.insert [[table[:id], false]]
        manager.to_sql.should be_like %{
          INSERT INTO "users" ("id") VALUES ('f')
        }
      end

      it "inserts null" do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine
        manager.insert [[table[:id], nil]]
        manager.to_sql.should be_like %{
          INSERT INTO "users" ("id") VALUES (NULL)
        }
      end

      it "inserts time" do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine

        time = Time.now
        manager.insert [[table[:id], time]]
        manager.to_sql.should be_like %{
          INSERT INTO "users" ("id") VALUES (#{Table.engine.connection.quote time})
        }
      end

      it 'takes a list of lists' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine
        manager.into table
        manager.insert [[table[:id], 1], [table[:name], 'aaron']]
        manager.to_sql.should be_like %{
          INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
        }
      end

      it 'defaults the table' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine
        manager.insert [[table[:id], 1], [table[:name], 'aaron']]
        manager.to_sql.should be_like %{
          INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
        }
      end

      it 'takes an empty list' do
        manager = Arel::InsertManager.new Table.engine
        manager.insert []
      end
    end

    describe 'into' do
      it 'takes an engine' do
        manager = Arel::InsertManager.new Table.engine
        manager.into(Table.new(:users)).should == manager
      end

      it 'converts to sql' do
        table   = Table.new :users
        manager = Arel::InsertManager.new Table.engine
        manager.into table
        manager.to_sql.should be_like %{
          INSERT INTO "users"
        }
      end
    end

    describe 'columns' do
      it "converts to sql" do
        table   = Table.new :users
        manager = Arel::InsertManager.new Table.engine
        manager.into table
        manager.columns << table[:id]
        manager.to_sql.should be_like %{
          INSERT INTO "users" ("id")
        }
      end
    end

    describe "values" do
      it "converts to sql" do
        table   = Table.new :users
        manager = Arel::InsertManager.new Table.engine
        manager.into table

        manager.values = Nodes::Values.new [1]
        manager.to_sql.should be_like %{
          INSERT INTO "users" VALUES (1)
        }
      end
    end

    describe "combo" do
      it "puts shit together" do
        table   = Table.new :users
        manager = Arel::InsertManager.new Table.engine
        manager.into table

        manager.values = Nodes::Values.new [1, 'aaron']
        manager.columns << table[:id]
        manager.columns << table[:name]
        manager.to_sql.should be_like %{
          INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
        }
      end
    end

    describe "TreeManager" do
      subject do
        table = Table.new(:users)
        Arel::InsertManager.new(Table.engine).tap do |manager|
          manager.insert [[table[:id], nil]]
        end
      end

      it_should_behave_like "TreeManager"
    end
  end
end
