# frozen_string_literal: true

require 'cases/helper'
require 'support/schema_dumping_helper'

class PostgresqlCollationTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table :postgresql_collations, force: true do |t|
      t.string :string_c, collation: 'C'
      t.text :text_posix, collation: 'POSIX'
    end
  end

  def teardown
    @connection.drop_table :postgresql_collations, if_exists: true
  end

  test 'string column with collation' do
    column = @connection.columns(:postgresql_collations).find { |c| c.name == 'string_c' }
    assert_equal :string, column.type
    assert_equal 'C', column.collation
  end

  test 'text column with collation' do
    column = @connection.columns(:postgresql_collations).find { |c| c.name == 'text_posix' }
    assert_equal :text, column.type
    assert_equal 'POSIX', column.collation
  end

  test 'add column with collation' do
    @connection.add_column :postgresql_collations, :title, :string, collation: 'C'

    column = @connection.columns(:postgresql_collations).find { |c| c.name == 'title' }
    assert_equal :string, column.type
    assert_equal 'C', column.collation
  end

  test 'change column with collation' do
    @connection.add_column :postgresql_collations, :description, :string
    @connection.change_column :postgresql_collations, :description, :text, collation: 'POSIX'

    column = @connection.columns(:postgresql_collations).find { |c| c.name == 'description' }
    assert_equal :text, column.type
    assert_equal 'POSIX', column.collation
  end

  test 'schema dump includes collation' do
    output = dump_table_schema('postgresql_collations')
    assert_match %r{t\.string\s+"string_c",\s+collation: "C"$}, output
    assert_match %r{t\.text\s+"text_posix",\s+collation: "POSIX"$}, output
  end
end
