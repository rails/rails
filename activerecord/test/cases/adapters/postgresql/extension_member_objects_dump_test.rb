# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"
require "active_support/core_ext/object/with"

class PostgresqlExtensionMemberObjectsDumpTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  self.use_transactional_tests = false

  def setup
    @connection = ActiveRecord::Base.lease_connection
    enable_extension!("hstore", @connection)

    @connection.create_table("hstore_member_table")
    @connection.create_table("hstore_user_table") do |t|
      t.bigint "hstore_member_table_id"
      t.foreign_key "hstore_member_table"
    end
    @connection.create_enum("hstore_member_enum", ["foo"])
    @connection.create_enum("hstore_user_enum", ["foo"])
    # No extension shipped with PostgreSQL creates tables or enum types, so
    # attach our own to hstore. PostgreSQL then records them as extension
    # members, exactly like the tables `CREATE EXTENSION postgis` creates.
    @connection.execute("ALTER EXTENSION hstore ADD TABLE hstore_member_table")
    @connection.execute("ALTER EXTENSION hstore ADD TYPE hstore_member_enum")
    @connection.create_schema("hstore_member_schema")
    @connection.execute("ALTER EXTENSION hstore ADD SCHEMA hstore_member_schema")
  end

  def teardown
    @connection.drop_table("hstore_user_table", if_exists: true)
    @connection.disable_extension("hstore")
    @connection.drop_schema("hstore_member_schema", if_exists: true)
    @connection.drop_table("hstore_member_table", if_exists: true)
    @connection.drop_enum("hstore_member_enum", if_exists: true)
    @connection.drop_enum("hstore_user_enum", if_exists: true)
  end

  def test_does_not_dump_tables_that_are_extension_members
    output = dump_all_table_schema

    assert_not_includes output, 'create_table "hstore_member_table"'
    assert_includes output, 'create_table "hstore_user_table"'
    assert_includes output, 'add_foreign_key "hstore_user_table", "hstore_member_table"'
  end

  def test_does_not_dump_enum_types_that_are_extension_members
    output = dump_all_table_schema

    assert_not_includes output, 'create_enum "hstore_member_enum"'
    assert_includes output, 'create_enum "hstore_user_enum"'
  end

  def test_does_not_dump_objects_that_are_extension_members_in_other_schemas
    @connection.create_schema("ext_objects_schema")
    @connection.create_table("ext_objects_schema.member_table")
    # Schema-qualified, this name is longer than a 63-byte identifier.
    @connection.create_table("ext_objects_schema.member_table_whose_name_is_as_long_as_an_identifier_can_be")
    @connection.create_table("ext_objects_schema.user_table")
    @connection.create_enum("ext_objects_schema.member_enum", ["foo"])
    @connection.execute("ALTER EXTENSION hstore ADD TABLE ext_objects_schema.member_table")
    @connection.execute("ALTER EXTENSION hstore ADD TABLE ext_objects_schema.member_table_whose_name_is_as_long_as_an_identifier_can_be")
    @connection.execute("ALTER EXTENSION hstore ADD TYPE ext_objects_schema.member_enum")

    ActiveRecord.with(dump_schemas: :all) do
      output = dump_all_table_schema

      assert_not_includes output, 'create_table "ext_objects_schema.member_table"'
      assert_not_includes output, "member_table_whose_name_is_as_long_as_an_identifier_can_be"
      assert_includes output, 'create_table "ext_objects_schema.user_table"'
      assert_not_includes output, 'create_enum "ext_objects_schema.member_enum"'
      assert_not_includes output, 'create_table "hstore_member_table"'
      assert_includes output, 'create_table "hstore_user_table"'
    end
  ensure
    @connection.drop_table("hstore_user_table", if_exists: true)
    @connection.disable_extension("hstore")
    @connection.drop_schema("ext_objects_schema", if_exists: true)
  end

  def test_does_not_dump_schemas_that_are_extension_members
    @connection.create_schema("ext_objects_schema")

    ActiveRecord.with(dump_schemas: :all) do
      output = dump_all_table_schema

      assert_not_includes output, 'create_schema "hstore_member_schema"'
      assert_includes output, 'create_schema "ext_objects_schema"'
    end
  ensure
    @connection.drop_schema("ext_objects_schema", if_exists: true)
  end

  def test_extension_member_tables_are_still_visible_to_the_connection
    assert @connection.table_exists?("hstore_member_table")
    assert_includes @connection.tables, "hstore_member_table"
  end
end
