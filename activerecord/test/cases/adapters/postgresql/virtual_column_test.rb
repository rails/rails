# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.lease_connection.supports_virtual_columns?
  class PostgresqlVirtualColumnTest < ActiveRecord::PostgreSQLTestCase
    include SchemaDumpingHelper

    class VirtualColumn < ActiveRecord::Base
    end

    def setup
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table :virtual_columns, force: true do |t|
        t.string  :name
        t.virtual :upper_name,  type: :string,  as: "UPPER(name)", stored: true
        t.virtual :name_length, type: :integer, as: "LENGTH(name)", stored: true
        t.virtual :name_octet_length, type: :integer, as: "OCTET_LENGTH(name)", stored: true
        t.integer :column1
        t.virtual :column2, type: :integer, as: "column1 + 1", stored: true
      end
      VirtualColumn.create(name: "Rails")
    end

    def test_virtual_column_with_full_inserts
      partial_inserts_was = VirtualColumn.partial_inserts
      VirtualColumn.partial_inserts = false
      assert_nothing_raised do
        VirtualColumn.create!(name: "Rails")
      end
    ensure
      VirtualColumn.partial_inserts = partial_inserts_was
    end

    def teardown
      @connection.drop_table :virtual_columns, if_exists: true
      VirtualColumn.reset_column_information
    end

    def test_virtual_column
      column = VirtualColumn.columns_hash["upper_name"]
      assert_predicate column, :virtual?
      assert_equal "RAILS", VirtualColumn.take.upper_name
    end

    def test_stored_column
      column = VirtualColumn.columns_hash["name_length"]
      assert_predicate column, :virtual?
      assert_equal 5, VirtualColumn.take.name_length
    end

    def test_change_table
      @connection.change_table :virtual_columns do |t|
        t.virtual :lower_name, type: :string, as: "LOWER(name)", stored: true
      end
      VirtualColumn.reset_column_information
      column = VirtualColumn.columns_hash["lower_name"]
      assert_predicate column, :virtual?
      assert_equal "rails", VirtualColumn.take.lower_name
    end

    def test_non_persisted_column
      message = <<~MSG
        PostgreSQL currently does not support VIRTUAL (not persisted) generated columns.
        Specify 'stored: true' option for 'invalid_definition'
      MSG

      assert_raise ArgumentError, message do
        @connection.change_table :virtual_columns do |t|
          t.virtual :invalid_definition, type: :string, as: "LOWER(name)"
        end
      end
    end

    def test_schema_dumping
      output = dump_table_schema("virtual_columns")
      assert_match(/t\.virtual\s+"upper_name",\s+type: :string,\s+as: "upper\(\(name\)::text\)", stored: true$/i, output)
      assert_match(/t\.virtual\s+"name_length",\s+type: :integer,\s+as: "length\(\(name\)::text\)", stored: true$/i, output)
      assert_match(/t\.virtual\s+"name_octet_length",\s+type: :integer,\s+as: "octet_length\(\(name\)::text\)", stored: true$/i, output)
      assert_match(/t\.virtual\s+"column2",\s+type: :integer,\s+as: "\(column1 \+ 1\)", stored: true$/i, output)
    end

    def test_build_fixture_sql
      fixtures = ActiveRecord::FixtureSet.create_fixtures(FIXTURES_ROOT, :virtual_columns).first
      assert_equal 2, fixtures.size
    end
  end
end
