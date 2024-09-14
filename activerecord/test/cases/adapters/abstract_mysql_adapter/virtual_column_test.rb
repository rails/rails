# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if ActiveRecord::Base.lease_connection.supports_virtual_columns?
  class VirtualColumnTest < ActiveRecord::AbstractMysqlTestCase
    include SchemaDumpingHelper

    self.use_transactional_tests = false

    class VirtualColumn < ActiveRecord::Base
    end

    def setup
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table :virtual_columns, force: true do |t|
        t.string   :name
        t.virtual  :upper_name,  type: :string,  as: "UPPER(`name`)"
        t.virtual  :name_length, type: :integer, as: "LENGTH(`name`)", stored: true
        t.virtual  :name_octet_length, type: :integer, as: "OCTET_LENGTH(`name`)", stored: true
        t.json     :profile
        t.virtual  :profile_email, type: :string, as: "json_extract(`profile`,_utf8mb4'$.email')", stored: true
        t.datetime :time
        t.virtual  :time_mirror, type: :datetime, as: "`time`"
      end
      VirtualColumn.create(name: "Rails")
    end

    def teardown
      @connection.drop_table :virtual_columns, if_exists: true
      VirtualColumn.reset_column_information
    end

    def test_virtual_column
      column = VirtualColumn.columns_hash["upper_name"]
      assert_predicate column, :virtual?
      assert_match %r{\bVIRTUAL\b}, column.extra
      assert_equal "RAILS", VirtualColumn.take.upper_name
    end

    def test_stored_column
      column = VirtualColumn.columns_hash["name_length"]
      assert_predicate column, :virtual?
      assert_match %r{\b(?:STORED|PERSISTENT)\b}, column.extra
      assert_equal 5, VirtualColumn.take.name_length
    end

    def test_change_table
      @connection.change_table :virtual_columns do |t|
        t.virtual :lower_name, type: :string, as: "LOWER(name)"
      end
      VirtualColumn.reset_column_information
      column = VirtualColumn.columns_hash["lower_name"]
      assert_predicate column, :virtual?
      assert_match %r{\bVIRTUAL\b}, column.extra
      assert_equal "rails", VirtualColumn.take.lower_name
    end

    def test_schema_dumping
      output = dump_table_schema("virtual_columns")
      assert_match(/t\.virtual\s+"upper_name",\s+type: :string,\s+as: "(?:UPPER|UCASE)\(`name`\)"$/i, output)
      assert_match(/t\.virtual\s+"name_length",\s+type: :integer,\s+as: "(?:octet_length|length)\(`name`\)",\s+stored: true$/i, output)
      assert_match(/t\.virtual\s+"name_octet_length",\s+type: :integer,\s+as: "(?:octet_length|length)\(`name`\)",\s+stored: true$/i, output)
      assert_match(/t\.virtual\s+"profile_email",\s+type: :string,\s+as: "json_extract\(`profile`,\w*?'\$\.email'\)", stored: true$/i, output)
      assert_match(/t\.virtual\s+"time_mirror",\s+type: :datetime,\s+as: "`time`"$/i, output[/^.*time_mirror.*$/])
    end
  end
end
