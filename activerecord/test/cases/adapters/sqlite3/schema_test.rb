# frozen_string_literal: true

# SQLite3 can have attached databases, which behave the same as a schema in PostgreSQL
require "cases/helper"

class SQLite3SchemaTest < ActiveRecord::SQLite3TestCase

  class SchemaThing < ActiveRecord::Base
    self.table_name = "test_schema.things"
  end

  def setup
    original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Schema.define do
      execute "ATTACH DATABASE ':memory:' AS test_schema;"
      create_table "test_schema.things" do |t|
        t.integer :number
      end
    end
  ensure
    ActiveRecord::Migration.verbose = original_verbose
  end

  teardown do
    # To remove the attached databases, just wipe the connections.
    ActiveRecord::Base.clear_all_connections!
  end

  def test_create
    thing = SchemaThing.create!
    assert_equal 1, thing.id
  end

  def test_first
    SchemaThing.create!
    thing = SchemaThing.first
    assert_equal 1, thing.id
  end
end
