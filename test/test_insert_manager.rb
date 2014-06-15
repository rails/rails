require 'helper'

module Arel
  describe 'insert manager' do
    describe 'new' do
      it 'takes an engine' do
        Arel::InsertManager.new Table.engine
      end
    end

    describe 'insert' do
      it 'can create a Values node' do
        manager = Arel::InsertManager.new Table.engine
        values  = manager.create_values %w{ a b }, %w{ c d }

        assert_kind_of Arel::Nodes::Values, values
        assert_equal %w{ a b }, values.left
        assert_equal %w{ c d }, values.right
      end

      it 'allows sql literals' do
        manager        = Arel::InsertManager.new Table.engine
        manager.into Table.new(:users)
        manager.values = manager.create_values [Arel.sql('*')], %w{ a }
        manager.to_sql.must_be_like %{
          INSERT INTO \"users\" VALUES (*)
        }
      end

      it "inserts false" do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine

        manager.insert [[table[:bool], false]]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("bool") VALUES ('f')
        }
      end

      it "inserts null" do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine
        manager.insert [[table[:id], nil]]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id") VALUES (NULL)
        }
      end

      it "inserts time" do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine

        time = Time.now
        attribute = table[:created_at]

        manager.insert [[attribute, time]]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("created_at") VALUES (#{Table.engine.connection.quote time})
        }
      end

      it 'takes a list of lists' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine
        manager.into table
        manager.insert [[table[:id], 1], [table[:name], 'aaron']]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
        }
      end

      it 'defaults the table' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine
        manager.insert [[table[:id], 1], [table[:name], 'aaron']]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
        }
      end

      it 'noop for empty list' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new Table.engine
        manager.insert [[table[:id], 1]]
        manager.insert []
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id") VALUES (1)
        }
      end
    end

    describe 'into' do
      it 'takes a Table and chains' do
        manager = Arel::InsertManager.new Table.engine
        manager.into(Table.new(:users)).must_equal manager
      end

      it 'converts to sql' do
        table   = Table.new :users
        manager = Arel::InsertManager.new Table.engine
        manager.into table
        manager.to_sql.must_be_like %{
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
        manager.to_sql.must_be_like %{
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
        manager.to_sql.must_be_like %{
          INSERT INTO "users" VALUES (1)
        }
      end
    end

    describe "combo" do
      it "combines columns and values list in order" do
        table   = Table.new :users
        manager = Arel::InsertManager.new Table.engine
        manager.into table

        manager.values = Nodes::Values.new [1, 'aaron']
        manager.columns << table[:id]
        manager.columns << table[:name]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
        }
      end
    end

    describe "select" do

      it "accepts a select query in place of a VALUES clause" do
        table   = Table.new :users

        manager = Arel::InsertManager.new Table.engine
        manager.into table

        select = Arel::SelectManager.new Table.engine
        select.project Arel.sql('1')
        select.project Arel.sql('"aaron"')

        manager.select select
        manager.columns << table[:id]
        manager.columns << table[:name]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id", "name") (SELECT 1, "aaron")
        }
      end

    end

  end
end
