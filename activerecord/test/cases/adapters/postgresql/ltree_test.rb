# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlLtreeTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper
  class Ltree < ActiveRecord::Base
    self.table_name = "ltrees"
  end

  def setup
    @connection = ActiveRecord::Base.lease_connection

    enable_extension!("ltree", @connection)

    @connection.create_table("ltrees") do |t|
      t.ltree "path"
    end
  end

  teardown do
    @connection.drop_table "ltrees", if_exists: true
  end

  def test_column
    column = Ltree.columns_hash["path"]
    assert_equal :ltree, column.type
    assert_equal "ltree", column.sql_type
    assert_not_predicate column, :array?

    type = Ltree.type_for_attribute("path")
    assert_not_predicate type, :binary?
  end

  def test_add_array_column_with_default
    # The extension array type isn't in the type map yet, so the default must be
    # quoted through a type loaded on demand rather than the string fallback.
    @connection.reload_type_map
    @connection.add_column "ltrees", "paths", :ltree, array: true, default: ["1.2"]
    Ltree.reset_column_information

    assert_equal ["1.2"], Ltree.new.paths
  end

  def test_write
    ltree = Ltree.new(path: "1.2.3.4")
    assert ltree.save!
  end

  def test_select
    @connection.execute "insert into ltrees (path) VALUES ('1.2.3')"
    ltree = Ltree.first
    assert_equal "1.2.3", ltree.path
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema("ltrees")
    assert_match %r[t\.ltree "path"], output
  end
end
