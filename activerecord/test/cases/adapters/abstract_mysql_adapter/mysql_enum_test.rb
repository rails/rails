# frozen_string_literal: true

require "cases/helper"
require "cases/enum_shared_test_cases"

module MySQLSharedEnumTestCases
  include SharedEnumTestCases

  def test_should_not_be_unsigned
    column = EnumTest.columns_hash["current_mood"]
    assert_not_predicate column, :unsigned?
  end

  def test_should_not_be_bigint
    column = EnumTest.columns_hash["current_mood"]
    assert_not_predicate column, :bigint?
  end

  def test_schema_dumping
    schema = dump_table_schema "enum_tests"
    assert_match %r{t\.enum "current_mood", default: "sad", values: \["sad", "ok", "happy"\]}, schema
  end
end

class MySQLEnumTest < ActiveRecord::AbstractMysqlTestCase
  include MySQLSharedEnumTestCases

  self.use_transactional_tests = false

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table :enum_tests, force: true do |t|
      t.column :current_mood, 'enum("sad","ok","happy")', default: "sad"
    end
  end

  def test_schema_load
    original, $stdout = $stdout, StringIO.new

    ActiveRecord::Schema.define do
      create_enum :color, ["blue", "green"]

      change_table :enum_tests do |t|
        t.enum :best_color, enum_type: "color", values: ["blue", "green"], default: "blue", null: false
      end
    end

    assert @connection.column_exists?(:enum_tests, :best_color, "string", values: ["blue", "green"], default: "blue", null: false)
  ensure
    $stdout = original
  end

  def test_enum_column_without_values_raises_error
    error = assert_raises(ArgumentError) do
      @connection.add_column :enum_tests, :best_color, :enum, null: false
    end

    assert_equal "values are required for enums", error.message
  end
end

class MySQLEnumWithValuesTest < ActiveRecord::AbstractMysqlTestCase
  include MySQLSharedEnumTestCases

  self.use_transactional_tests = false
end
