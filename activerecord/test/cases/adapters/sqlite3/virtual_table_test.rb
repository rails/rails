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

  def test_schema_dump_ignores_virtual_tables_in_ignore_tables
    output = dump_all_table_schema(["searchables"])

    assert_not_includes output, 'create_virtual_table "searchables"'
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

  def test_virtual_table_regex_matches_empty_parentheses
    regex = ActiveRecord::ConnectionAdapters::SQLite3Adapter::VIRTUAL_TABLE_REGEX

    match = "CREATE VIRTUAL TABLE foo USING bar()".match(regex)
    assert_not_nil match
    assert_equal "bar", match[1]
    assert_equal "", match[2]
  end

  def test_schema_dump_with_multiline_virtual_table_definition
    @connection.drop_table :multiline_search, if_exists: true
    @connection.execute(<<~SQL)
      CREATE VIRTUAL TABLE multiline_search USING fts5(
        title,
        body,
        tokenize='porter unicode61'
      )
    SQL

    output = dump_all_table_schema

    assert_includes output, 'create_virtual_table "multiline_search", "fts5", ["title", "body", "tokenize=\'porter unicode61\'"]'
  ensure
    @connection.drop_table :multiline_search, if_exists: true
  end

  def test_virtual_table_regex_matches_squished_multiline_definitions
    regex = ActiveRecord::ConnectionAdapters::SQLite3Adapter::VIRTUAL_TABLE_REGEX

    sql = "CREATE VIRTUAL TABLE foo USING fts5(\n  title,\n  body,\n  tokenize='porter unicode61'\n)"
    match = sql.squish.match(regex)
    assert_not_nil match
    assert_equal "fts5", match[1]
    assert_equal "title, body, tokenize='porter unicode61'", match[2].strip
  end
end
