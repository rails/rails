# frozen_string_literal: true

require 'cases/helper'
require 'support/schema_dumping_helper'

class Mysql2EnumTest < ActiveRecord::Mysql2TestCase
  self.use_transactional_tests = false

  include SchemaDumpingHelper

  class EnumTest < ActiveRecord::Base
    attribute :state, :integer

    enum state: {
      start: 0,
      middle: 1,
      finish: 2
    }
  end

  def setup
    EnumTest.connection.create_table :enum_tests, id: false, force: true do |t|
      t.column :enum_column, "enum('text','blob','tiny','medium','long','unsigned','bigint')"
      t.column :state, 'TINYINT(1)'
    end
  end

  def test_should_not_be_unsigned
    column = EnumTest.columns_hash['enum_column']
    assert_not_predicate column, :unsigned?
  end

  def test_should_not_be_bigint
    column = EnumTest.columns_hash['enum_column']
    assert_not_predicate column, :bigint?
  end

  def test_schema_dumping
    schema = dump_table_schema 'enum_tests'
    assert_match %r{t\.column "enum_column", "enum\('text','blob','tiny','medium','long','unsigned','bigint'\)"$}, schema
  end

  def test_enum_with_attribute
    enum_test = EnumTest.create!(state: :middle)
    assert_equal 'middle', enum_test.state
  end
end
