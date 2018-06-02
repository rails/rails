# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class Mysql2AutoIncrementTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.drop_table :auto_increments, if_exists: true
  end

  def test_auto_increment_without_primary_key
    @connection.create_table :auto_increments, id: false, force: true do |t|
      t.integer :id, null: false, auto_increment: true
      t.index :id
    end
    output = dump_table_schema("auto_increments")
    assert_match(/t\.integer\s+"id",\s+null: false,\s+auto_increment: true$/, output)
  end

  def test_auto_increment_with_composite_primary_key
    @connection.create_table :auto_increments, primary_key: [:id, :created_at], force: true do |t|
      t.integer :id, null: false, auto_increment: true
      t.datetime :created_at, null: false
    end
    output = dump_table_schema("auto_increments")
    assert_match(/t\.integer\s+"id",\s+null: false,\s+auto_increment: true$/, output)
  end
end
