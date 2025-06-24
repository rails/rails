# frozen_string_literal: true

require "cases/helper"

class PostgresqlRenameTableTest < ActiveRecord::PostgreSQLTestCase
  def setup
    @connection = ActiveRecord::Base.lease_connection
  end

  def teardown
    @connection.drop_table "before_rename", if_exists: true
    @connection.drop_table "after_rename", if_exists: true
  end

  test "renaming a table also renames the primary key sequence" do
    @connection.create_table :before_rename, force: true

    @connection.rename_table :before_rename, :after_rename

    pk, seq = @connection.pk_and_sequence_for("after_rename")
    assert_equal "after_rename_#{pk}_seq", seq.identifier
  end

  test "renaming a table also renames the primary key index" do
    @connection.create_table :before_rename, force: true

    assert_renames_index("before_rename_pkey", "after_rename_pkey") do
      @connection.rename_table :before_rename, :after_rename
    end
  end

  test "renaming a table with uuid primary key and uuid_generate_v4() default also renames the primary key index" do
    @connection.create_table :before_rename, force: true, id: :uuid, default: -> { "uuid_generate_v4()" }

    assert_renames_index("before_rename_pkey", "after_rename_pkey") do
      @connection.rename_table :before_rename, :after_rename
    end
  end

  test "renaming a table with uuid primary key and gen_random_uuid() default also renames the primary key index" do
    @connection.create_table :before_rename, force: true, id: :uuid, default: -> { "gen_random_uuid()" }

    assert_renames_index("before_rename_pkey", "after_rename_pkey") do
      @connection.rename_table :before_rename, :after_rename
    end
  end

  private
    def assert_renames_index(from, to, &block)
      assert_changes(-> { num_indices_named(from) }, from: 1, to: 0) do
        assert_changes(-> { num_indices_named(to) }, from: 0, to: 1, &block)
      end
    end

    def num_indices_named(name)
      @connection.execute(<<~SQL).values.length
        SELECT 1 FROM "pg_index"
          JOIN "pg_class" ON "pg_index"."indexrelid" = "pg_class"."oid"
          WHERE "pg_class"."relname" = '#{name}'
      SQL
    end
end
