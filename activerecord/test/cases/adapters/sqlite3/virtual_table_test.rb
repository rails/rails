# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class SQLite3VirtualTableTest < ActiveRecord::SQLite3TestCase
  include SchemaDumpingHelper

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_virtual_table :searchables, :fts5, ["content", "meta UNINDEXED", "tokenize='porter ascii'"]
  end

  def teardown
    @connection.drop_table :searchables, if_exists: true
  end

  def test_schema_dump
    output = dump_all_table_schema

    assert_not_includes output, "searchables_docsize"
    assert_includes output, 'create_virtual_table "searchables", "fts5", ["content", "meta UNINDEXED", "tokenize=\'porter ascii\'"]'
  end

  def test_schema_load
    original, $stdout = $stdout, StringIO.new

    ActiveRecord::Schema.define do
      create_virtual_table :emails, :fts5, ["content", "meta UNINDEXED"]
    end

    assert @connection.virtual_table_exists?(:emails)
  ensure
    $stdout = original
  end

  def test_virtual_table_regex_parses_empty_parentheses
    regex = ActiveRecord::ConnectionAdapters::SQLite3Adapter::VIRTUAL_TABLE_REGEX

    _, module_name, arguments = "CREATE VIRTUAL TABLE t USING SomeModule()".match(regex).to_a
    assert_equal "SomeModule", module_name
    assert_equal "", arguments
    assert_equal [], arguments.split(", ")
  end
end
