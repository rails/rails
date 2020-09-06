# frozen_string_literal: true

require 'cases/helper'
require 'support/schema_dumping_helper'

class Mysql2SetTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper

  class SetTest < ActiveRecord::Base
  end

  def setup
    SetTest.connection.create_table :set_tests, id: false, force: true do |t|
      t.column :set_column, "set('text','blob','tiny','medium','long','unsigned','bigint')"
    end
  end

  def test_should_not_be_unsigned
    column = SetTest.columns_hash['set_column']
    assert_not_predicate column, :unsigned?
  end

  def test_should_not_be_bigint
    column = SetTest.columns_hash['set_column']
    assert_not_predicate column, :bigint?
  end

  def test_schema_dumping
    schema = dump_table_schema 'set_tests'
    assert_match %r{t\.column "set_column", "set\('text','blob','tiny','medium','long','unsigned','bigint'\)"$}, schema
  end
end
