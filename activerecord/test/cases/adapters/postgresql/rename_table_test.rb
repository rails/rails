require "cases/helper"

class PostgresqlRenameTableTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table :before_rename, force: true
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS "before_rename"'
    @connection.execute 'DROP TABLE IF EXISTS "after_rename"'
  end

  test "renaming a table also renames the primary key index" do
    # sanity check
    assert_equal 1, num_indices_named("before_rename_pkey")
    assert_equal 0, num_indices_named("after_rename_pkey")

    @connection.rename_table :before_rename, :after_rename

    assert_equal 0, num_indices_named("before_rename_pkey")
    assert_equal 1, num_indices_named("after_rename_pkey")
  end

  private

  def num_indices_named(name)
    @connection.execute(<<-SQL).values.length
      SELECT 1 FROM "pg_index"
        JOIN "pg_class" ON "pg_index"."indexrelid" = "pg_class"."oid"
        WHERE "pg_class"."relname" = '#{name}'
    SQL
  end
end
