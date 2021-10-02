# frozen_string_literal: true

require "cases/helper"

class PostgresqlRenameTableTest < ActiveRecord::PostgreSQLTestCase
  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table :before_rename, force: true
  end

  def teardown
    @connection.drop_table "before_rename", if_exists: true
    @connection.drop_table "after_rename", if_exists: true
  end

  test "renaming a table also renames the primary key index" do
    assert_changes(-> { num_indices_named("before_rename_pkey") }, from: 1, to: 0) do
      assert_changes(-> { num_indices_named("after_rename_pkey") }, from: 0, to: 1) do
        @connection.rename_table :before_rename, :after_rename
      end
    end
  end

  private
    def num_indices_named(name)
      @connection.execute(<<~SQL).values.length
        SELECT 1 FROM "pg_index"
          JOIN "pg_class" ON "pg_index"."indexrelid" = "pg_class"."oid"
          WHERE "pg_class"."relname" = '#{name}'
      SQL
    end
end
