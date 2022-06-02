# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class Mysql2CharsetCollationTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper
  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table :charset_collations, id: { type: :string, collation: "utf8mb4_bin" }, force: true do |t|
      t.string :string_ascii_bin, charset: "ascii", collation: "ascii_bin"
      t.text :text_ucs2_unicode_ci, charset: "ucs2", collation: "ucs2_unicode_ci"
    end
  end

  teardown do
    @connection.drop_table :charset_collations, if_exists: true
  end

  test "string column with charset and collation" do
    column = @connection.columns(:charset_collations).find { |c| c.name == "string_ascii_bin" }
    assert_equal :string, column.type
    assert_equal "ascii_bin", column.collation
  end

  test "text column with charset and collation" do
    column = @connection.columns(:charset_collations).find { |c| c.name == "text_ucs2_unicode_ci" }
    assert_equal :text, column.type
    assert_equal "ucs2_unicode_ci", column.collation
  end

  test "add column with charset and collation" do
    @connection.add_column :charset_collations, :title, :string, charset: "utf8mb4", collation: "utf8mb4_bin"

    column = @connection.columns(:charset_collations).find { |c| c.name == "title" }
    assert_equal :string, column.type
    assert_equal "utf8mb4_bin", column.collation
  end

  test "change column with charset and collation" do
    @connection.add_column :charset_collations, :description, :string, charset: "utf8mb4", collation: "utf8mb4_unicode_ci"
    @connection.change_column :charset_collations, :description, :text, charset: "utf8mb4", collation: "utf8mb4_general_ci"

    column = @connection.columns(:charset_collations).find { |c| c.name == "description" }
    assert_equal :text, column.type
    assert_equal "utf8mb4_general_ci", column.collation
  end

  test "schema dump includes collation" do
    output = dump_table_schema("charset_collations")
    assert_match %r/create_table "charset_collations", id: { type: :string, collation: "utf8mb4_bin" }/, output
    assert_match %r{t\.string\s+"string_ascii_bin",\s+collation: "ascii_bin"$}, output
    assert_match %r{t\.text\s+"text_ucs2_unicode_ci",\s+collation: "ucs2_unicode_ci"$}, output
  end
end
