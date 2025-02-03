# frozen_string_literal: true

require "cases/helper"
require "cases/enum_shared_test_cases"

class EnumTest < ActiveRecord::SQLite3TestCase
  include SharedEnumTestCases

  def test_schema_dump
    schema = dump_table_schema "enum_tests"
    assert_match %r{t\.string "current_mood", default: "sad"}, schema
  end

  def test_schema_load
    original, $stdout = $stdout, StringIO.new

    ActiveRecord::Schema.define do
      create_enum :color, ["blue", "green"]

      change_table :enum_tests do |t|
        t.enum :best_color, enum_type: "color", values: ["blue", "green"], default: "blue", null: false
      end
    end

    assert @connection.column_exists?(:enum_tests, :best_color, "string", default: "blue", null: false)
  ensure
    $stdout = original
  end
end
