# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"
require "active_support/core_ext/object/with"

class PostgresqlExtensionSchemaDumpTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  self.use_transactional_tests = false

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @connection.disable_extension("hstore", force: :cascade)
    @connection.create_schema("extension_schema")
    # hstore is relocatable: its control file does not fix the schema.
    @connection.enable_extension("extension_schema.hstore")
  end

  def teardown
    @connection.disable_extension("hstore", force: :cascade)
    @connection.drop_schema("extension_schema", if_exists: true)
  end

  def test_dumps_schema_of_an_extension_that_dump_schemas_leaves_out
    output = ActiveRecord.with(dump_schemas: "public") { dump_all_table_schema }

    assert_includes output, 'create_schema "extension_schema", if_not_exists: true'
    assert_includes output, 'enable_extension "extension_schema.hstore"'
    assert_operator output.index("create_schema"), :<, output.index('enable_extension "extension_schema.hstore"')
  end

  def test_dumps_schema_once_when_dump_schemas_includes_it
    output = ActiveRecord.with(dump_schemas: :all) { dump_all_table_schema }

    assert_includes output, 'create_schema "extension_schema"'
    assert_not_includes output, "if_not_exists"
  end

  def test_does_not_dump_system_schemas
    output = ActiveRecord.with(dump_schemas: "public") { dump_all_table_schema }

    assert_no_match(/create_schema "pg_/, output)
  end
end
