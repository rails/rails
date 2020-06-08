# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class Mysql2EnumTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper

  class EnumTest < ActiveRecord::Base
  end

  def setup
    EnumTest.connection.create_table :enum_tests, id: false, force: true do |t|
      t.column :enum_column, "enum('text','blob','tiny','medium','long','unsigned','bigint')"
    end
  end

  def test_should_not_be_unsigned
    column = EnumTest.columns_hash["enum_column"]
    assert_not_predicate column, :unsigned?
  end

  def test_should_not_be_bigint
    column = EnumTest.columns_hash["enum_column"]
    assert_not_predicate column, :bigint?
  end

  def test_schema_dumping
    schema = dump_table_schema "enum_tests"
    assert_match %r{t\.column "enum_column", "enum\('text','blob','tiny','medium','long','unsigned','bigint'\)"$}, schema
  end
end
