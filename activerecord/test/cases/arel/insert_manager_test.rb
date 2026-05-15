# frozen_string_literal: true

require_relative "helper"
require_relative "support/tree_manager_behavior"

module Arel
  class InsertManagerTest < Arel::Test
    include TreeManagerBehavior

    test "insert can create a ValuesList node" do
      manager = Arel::InsertManager.new
      values  = manager.create_values_list([%w{ a b }, %w{ c d }])

      assert_kind_of Arel::Nodes::ValuesList, values
      assert_equal [%w{ a b }, %w{ c d }], values.rows
    end

    test "insert allows sql literals" do
      manager = Arel::InsertManager.new
      manager.into Table.new(:users)
      manager.values = manager.create_values([Arel.sql("*")])

      assert_like %{
        INSERT INTO "users" VALUES (*)
      }, manager.to_sql
    end

    test "insert works with multiple values" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new
      manager.into table

      manager.columns << table[:id]
      manager.columns << table[:name]

      manager.values = manager.create_values_list([
        %w{1 david},
        %w{2 kir},
        ["3", Arel.sql("DEFAULT")],
      ])

      assert_like %{
        INSERT INTO "users" ("id", "name") VALUES ('1', 'david'), ('2', 'kir'), ('3', DEFAULT)
      }, manager.to_sql
    end

    test "insert literals in multiple values are not escaped" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new
      manager.into table

      manager.columns << table[:name]

      manager.values = manager.create_values_list([
        [Arel.sql("*")],
        [Arel.sql("DEFAULT")],
      ])

      assert_like %{
        INSERT INTO "users" ("name") VALUES (*), (DEFAULT)
      }, manager.to_sql
    end

    test "insert works with multiple single values" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new
      manager.into table

      manager.columns << table[:name]

      manager.values = manager.create_values_list([
        %w{david},
        %w{kir},
        [Arel.sql("DEFAULT")],
      ])

      assert_like %{
        INSERT INTO "users" ("name") VALUES ('david'), ('kir'), (DEFAULT)
      }, manager.to_sql
    end

    test "insert inserts false" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new

      manager.insert [[table[:bool], false]]
      assert_like %{
        INSERT INTO "users" ("bool") VALUES ('f')
      }, manager.to_sql
    end

    test "insert inserts null" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new
      manager.insert [[table[:id], nil]]

      assert_like %{
        INSERT INTO "users" ("id") VALUES (NULL)
      }, manager.to_sql
    end

    test "insert inserts time" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new

      time = Time.now
      attribute = table[:created_at]

      manager.insert [[attribute, time]]
      assert_like %{
        INSERT INTO "users" ("created_at") VALUES (#{Table.engine.lease_connection.quote time})
      }, manager.to_sql
    end

    test "insert takes a list of lists" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new
      manager.into table
      manager.insert [[table[:id], 1], [table[:name], "aaron"]]

      assert_like %{
        INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
      }, manager.to_sql
    end

    test "insert defaults the table" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new
      manager.insert [[table[:id], 1], [table[:name], "aaron"]]

      assert_like %{
        INSERT INTO "users" ("id", "name") VALUES (1, 'aaron')
      }, manager.to_sql
    end

    test "insert noop for empty list" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new
      manager.insert [[table[:id], 1]]
      manager.insert []

      assert_like %{
        INSERT INTO "users" ("id") VALUES (1)
      }, manager.to_sql
    end

    test "insert is chainable" do
      table = Table.new(:users)
      manager = Arel::InsertManager.new
      insert_result = manager.insert [[table[:id], 1]]

      assert_equal manager, insert_result
    end

    test "into takes a Table and chains" do
      manager = Arel::InsertManager.new

      assert_equal manager, manager.into(Table.new(:users))
    end

    test "into converts to sql" do
      table   = Table.new :users
      manager = Arel::InsertManager.new
      manager.into table

      assert_like %{
        INSERT INTO "users"
      }, manager.to_sql
    end

    test "columns converts to sql" do
      table   = Table.new :users
      manager = Arel::InsertManager.new
      manager.into table
      manager.columns << table[:id]

      assert_like %{
        INSERT INTO "users" ("id")
      }, manager.to_sql
    end

    test "values converts to sql" do
      table   = Table.new :users
      manager = Arel::InsertManager.new
      manager.into table
      manager.values = Nodes::ValuesList.new([[1], [2]])

      assert_like %{
        INSERT INTO "users" VALUES (1), (2)
      }, manager.to_sql
    end

    test "values accepts sql literals" do
      table   = Table.new :users
      manager = Arel::InsertManager.new
      manager.into table
      manager.values = Arel.sql("DEFAULT VALUES")

      assert_like %{
        INSERT INTO "users" DEFAULT VALUES
      }, manager.to_sql
    end

    test "combo combines columns and values list in order" do
      table   = Table.new :users
      manager = Arel::InsertManager.new
      manager.into table

      manager.values = Nodes::ValuesList.new([[1, "aaron"], [2, "david"]])
      manager.columns << table[:id]
      manager.columns << table[:name]

      assert_like %{
        INSERT INTO "users" ("id", "name") VALUES (1, 'aaron'), (2, 'david')
      }, manager.to_sql
    end

    test "select accepts a select query in place of a VALUES clause" do
      table   = Table.new :users
      manager = Arel::InsertManager.new
      manager.into table

      select = Arel::SelectManager.new
      select.project Arel.sql("1")
      select.project Arel.sql('"aaron"')

      manager.select select
      manager.columns << table[:id]
      manager.columns << table[:name]

      assert_like %{
        INSERT INTO "users" ("id", "name") (SELECT 1, "aaron")
      }, manager.to_sql
    end

    test "#returning accepts a returning clause" do
      users   = Table.new :users
      manager = Arel::InsertManager.new
      manager.into users
      manager.returning Arel.star

      assert_like %{
        INSERT INTO "users" RETURNING *
      }, manager.to_sql
    end

    test "#returning accepts multiple values as returning clause" do
      users   = Table.new :users
      manager = Arel::InsertManager.new
      manager.into users
      manager.returning Arel.star
      manager.returning [users[:id], users[:name]]

      assert_like %{
        INSERT INTO "users" RETURNING *, "users"."id", "users"."name"
      }, manager.to_sql
    end

    test "#returning chains" do
      manager = Arel::InsertManager.new
      assert_equal manager, manager.returning(Arel.star)
    end

    private
      def build_manager(table = nil)
        Arel::InsertManager.new(table)
      end
  end
end
