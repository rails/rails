# frozen_string_literal: true
require_relative 'helper'

module Arel
  class InsertManagerTest < Arel::Spec
    describe 'new' do
      it 'takes an engine' do
        Arel::InsertManager.new
      end
    end

    describe 'insert' do
      it 'can create a Values node' do
        manager = Arel::InsertManager.new
        values  = manager.create_values %w{ a b }, %w{ c d }

        assert_kind_of Arel::Nodes::Values, values
        assert_equal %w{ a b }, values.left
        assert_equal %w{ c d }, values.right
      end

      it 'allows sql literals' do
        manager        = Arel::InsertManager.new
        manager.into Table.new(:users)
        manager.values = manager.create_values [Arel.sql('*')], %w{ a }
        manager.to_sql.must_be_like %{
          INSERT INTO \"users\" VALUES (*)
        }
      end

      it 'works with multiple values' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new
        manager.into table

        manager.columns << table[:id]
        manager.columns << table[:name]

        manager.values = manager.create_values_list([
          %w{1 david},
          %w{2 kir},
          ["3", Arel.sql('DEFAULT')],
        ])

        manager.to_sql.must_be_like %{
          INSERT INTO \"users\" (\"id\", \"name\") VALUES ('1', 'david'), ('2', 'kir'), ('3', DEFAULT)
        }
      end

      it 'literals in multiple values are not escaped' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new
        manager.into table

        manager.columns << table[:name]

        manager.values = manager.create_values_list([
          [Arel.sql('*')],
          [Arel.sql('DEFAULT')],
        ])

        manager.to_sql.must_be_like %{
          INSERT INTO \"users\" (\"name\") VALUES (*), (DEFAULT)
        }
      end

      it 'works with multiple single values' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new
        manager.into table

        manager.columns << table[:name]

        manager.values = manager.create_values_list([
          %w{david},
          %w{kir},
          [Arel.sql('DEFAULT')],
        ])

        manager.to_sql.must_be_like %{
          INSERT INTO \"users\" (\"name\") VALUES ('david'), ('kir'), (DEFAULT)
        }
      end

      it "inserts false" do
        table = Table.new(:users)
        manager = Arel::InsertManager.new

        manager.insert [[table[:bool], false]]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("bool") VALUES ('f')
        }
      end

      it "inserts null" do
        table = Table.new(:users)
        manager = Arel::InsertManager.new
        manager.insert [[table[:id], nil]]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id") VALUES (NULL)
        }
      end

      it "inserts time" do
        table = Table.new(:users)
        manager = Arel::InsertManager.new

        time = Time.now
        attribute = table[:created_at]

        manager.insert [[attribute, time]]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("created_at") VALUES (#{Table.engine.connection.quote time})
        }
      end

      it 'takes a list of lists' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new
        manager.into table
        manager.insert [[table[:id], 1], [table[:name], 'aaron']]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
        }
      end

      it 'defaults the table' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new
        manager.insert [[table[:id], 1], [table[:name], 'aaron']]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
        }
      end

      it 'noop for empty list' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new
        manager.insert [[table[:id], 1]]
        manager.insert []
        manager.to_sql.must_be_like %{
          INSERT INTO "users" ("id") VALUES (1)
        }
      end

      it 'is chainable' do
        table = Table.new(:users)
        manager = Arel::InsertManager.new
        insert_result = manager.insert [[table[:id],1]]
        assert_equal manager, insert_result
      end
    end

    describe 'into' do
      it 'takes a Table and chains' do
        manager = Arel::InsertManager.new
        manager.into(Table.new(:users)).must_equal manager
      end

      it 'converts to sql' do
        table   = Table.new :users
        manager = Arel::InsertManager.new
        manager.into table
        manager.to_sql.must_be_like %{
          INSERT INTO "users"
        }
      end
    end

    describe 'columns' do
      it "converts to sql" do
        table   = Table.new :users
        manager = Arel::InsertManager.new
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
        manager = Arel::InsertManager.new
        manager.into table

        manager.values = Nodes::Values.new [1]
        manager.to_sql.must_be_like %{
          INSERT INTO "users" VALUES (1)
        }
      end

      it "accepts sql literals" do
        table   = Table.new :users
        manager = Arel::InsertManager.new
        manager.into table

        manager.values = Arel.sql("DEFAULT VALUES")
        manager.to_sql.must_be_like %{
          INSERT INTO "users" DEFAULT VALUES
        }
      end
    end

    describe "combo" do
      it "combines columns and values list in order" do
        table   = Table.new :users
        manager = Arel::InsertManager.new
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

        manager = Arel::InsertManager.new
        manager.into table

        select = Arel::SelectManager.new
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
