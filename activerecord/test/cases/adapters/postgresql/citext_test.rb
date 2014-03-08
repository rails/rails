# encoding: utf-8

require 'cases/helper'
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlCitextTest < ActiveRecord::TestCase
  class CitextDataType < ActiveRecord::Base
    self.table_name = 'citext_data_type'
  end

  def setup
    @connection = ActiveRecord::Base.connection

    unless @connection.extension_enabled?('citext')
      @connection.enable_extension 'citext'
      @connection.commit_db_transaction
    end

    @connection.reconnect!

    @connection.transaction do
      @connection.create_table('citext_data_type')
      @connection.add_column :citext_data_type, :search_field, 'citext'
    end
    @column = CitextDataType.columns.find { |c| c.name == 'search_field' }
  end

  def teardown
    @connection.execute 'DROP TABLE IF EXISTS citext_data_type;'
    @connection.execute 'DROP EXTENSION IF EXISTS citext CASCADE;'
  end

  if ActiveRecord::Base.connection.supports_extensions?
    def test_citext_included_in_extensions
      assert @connection.respond_to?(:extensions),
        'connection should have a list of extensions'
      assert @connection.extensions.include?('citext'),
        'extension list should include citext'
    end

    def test_disable_enable_citext
      assert @connection.extension_enabled?('citext')
      @connection.disable_extension 'citext'
      assert_not @connection.extension_enabled?('citext')
      @connection.enable_extension 'citext'
      assert @connection.extension_enabled?('citext')
    end

    def test_column_type
      assert_equal :text, @column.type
    end

    def test_column_sql_type
      assert_equal 'citext', @column.sql_type
    end

    def test_no_oid_warning
      @connection.execute(
        "INSERT INTO citext_data_type (search_field) VALUES ('test');"
        )
      stderr_output = capture(:stderr) { CitextDataType.first }
      assert stderr_output.blank?
    end

    def test_write_and_case_insensitive_query
      string = 'FirstName LastName Tel Email'
      
      # test write
      new_record = CitextDataType.new(search_field: string)
      assert new_record.save!
      new_record.reload
      assert_equal(string, new_record.search_field)

      # test case insensitive query match returns original string
      query = CitextDataType.where(
        search_field: 'firstName Lastname tEl emaiL'
        )
      assert_not_equal [], query
      record = query.try(:first)
      assert_not_nil record
      assert_equal 1, record.id
      assert_equal string, record.search_field
    end
  end

end

