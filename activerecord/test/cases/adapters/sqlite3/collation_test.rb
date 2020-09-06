# frozen_string_literal: true

require 'cases/helper'
require 'support/schema_dumping_helper'

class SQLite3CollationTest < ActiveRecord::SQLite3TestCase
  include SchemaDumpingHelper

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table :collation_table_sqlite3, force: true do |t|
      t.string :string_nocase, collation: 'NOCASE'
      t.text :text_rtrim, collation: 'RTRIM'
      # The decimal column might interfere with collation parsing.
      # Thus, add this column type and some other string column afterwards.
      t.decimal :decimal_col, precision: 6, scale: 2
      t.string :string_after_decimal_nocase, collation: 'NOCASE'
    end
  end

  def teardown
    @connection.drop_table :collation_table_sqlite3, if_exists: true
  end

  test 'string column with collation' do
    column = @connection.columns(:collation_table_sqlite3).find { |c| c.name == 'string_nocase' }
    assert_equal :string, column.type
    assert_equal 'NOCASE', column.collation

    # Verify collation of a column behind the decimal column as well.
    column = @connection.columns(:collation_table_sqlite3).find { |c| c.name == 'string_after_decimal_nocase' }
    assert_equal :string, column.type
    assert_equal 'NOCASE', column.collation
  end

  test 'text column with collation' do
    column = @connection.columns(:collation_table_sqlite3).find { |c| c.name == 'text_rtrim' }
    assert_equal :text, column.type
    assert_equal 'RTRIM', column.collation
  end

  test 'add column with collation' do
    @connection.add_column :collation_table_sqlite3, :title, :string, collation: 'RTRIM'

    column = @connection.columns(:collation_table_sqlite3).find { |c| c.name == 'title' }
    assert_equal :string, column.type
    assert_equal 'RTRIM', column.collation
  end

  test 'change column with collation' do
    @connection.add_column :collation_table_sqlite3, :description, :string
    @connection.change_column :collation_table_sqlite3, :description, :text, collation: 'RTRIM'

    column = @connection.columns(:collation_table_sqlite3).find { |c| c.name == 'description' }
    assert_equal :text, column.type
    assert_equal 'RTRIM', column.collation
  end

  test 'schema dump includes collation' do
    output = dump_table_schema('collation_table_sqlite3')
    assert_match %r{t\.string\s+"string_nocase",\s+collation: "NOCASE"$}, output
    assert_match %r{t\.text\s+"text_rtrim",\s+collation: "RTRIM"$}, output
  end
end
