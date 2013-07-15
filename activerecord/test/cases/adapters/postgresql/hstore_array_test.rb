# encoding: utf-8
require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlHstoreArrayTest < ActiveRecord::TestCase
  class PgHstoreArray < ActiveRecord::Base
    self.table_name = 'pg_hstore_arrays'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    
    unless @connection.supports_extensions?
      return skip "do not test on PG without hstore"
    end

    unless @connection.extension_enabled?('hstore')
      @connection.enable_extension 'hstore'
      @connection.commit_db_transaction
    end

    @connection.reconnect!
    
    @connection.transaction do
      @connection.create_table('pg_hstore_arrays') do |t|
        t.hstore 'payload', array: true
      end
    end
    @column = PgHstoreArray.columns.find { |c| c.name == 'payload' }
    
    @t_data_hstore = '{"\"AA\"=>\"BB\",\"CC\"=>\"DD\"","\"AA\"=>NULL"}'
    @t_data_native = [{"AA" => "BB", "CC" => "DD"}, {"AA" => nil}]
  end

  def teardown
    @connection.execute 'drop table if exists pg_hstore_arrays'
  end

  def test_column
    assert_equal :hstore, @column.type
    assert @column.array
  end

  def test_change_column_with_hstore_array
    @connection.transaction do
      @connection.change_table('pg_hstore_arrays') do |t|
        t.hstore 'users', array: true
      end
      PgHstoreArray.reset_column_information
      column = PgHstoreArray.columns.find { |c| c.name == 'users' }
      assert_equal :hstore, column.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    PgHstoreArray.reset_column_information
  end

  def test_type_cast_hstore_array
    assert @column

    oid_type  = @column.instance_variable_get('@oid_type').subtype
    # we are getting the instance variable in this test, but in the
    # normal use of string_to_array, it's called from the OID::Array
    # class and will have the OID instance that will provide the type
    # casting
    array = @column.class.string_to_array @t_data_hstore, oid_type
    assert_equal(@t_data_native, array)
    assert_equal(@t_data_native, @column.type_cast(@t_data_hstore))

    assert_equal([], @column.type_cast('{}'))
    assert_equal(["key" => nil], @column.type_cast('{"\"key\"=>NULL"}'))
  end

  def test_rewrite
    @connection.execute "insert into pg_hstore_arrays (payload) VALUES ('#{@t_data_hstore}')"
    x = PgHstoreArray.first
    x.payload = [{"foo" => "bar"}, {"foo" => "baz", "quux" => nil}]
    assert x.save!
  end

  def test_select
    @connection.execute "insert into pg_hstore_arrays (payload) VALUES ('#{@t_data_hstore}')"
    x = PgHstoreArray.first
    assert_equal(@t_data_native, x.payload)
  end

  def test_indifferent_access
    @connection.execute "insert into pg_hstore_arrays (payload) VALUES ('#{@t_data_hstore}')"
    x = PgHstoreArray.first
    assert_equal("BB", x.payload[0][:AA])
    assert_equal(nil, x.payload[1][:AA])
  end

  def test_cycle
    assert_cycle(@t_data_native)
  end

  def test_strings_with_quotes
    assert_cycle([{'this has' => 'some "s that need to be escaped"'}])
  end

  def test_strings_with_commas
    assert_cycle([{'this,has' => 'many,values'}])
  end

  def test_strings_with_array_delimiters
    assert_cycle(['{' => '}'])
  end

  def test_strings_with_null_strings
    assert_cycle([{'NULL' => 'NULL'}])
  end

  def test_contains_nils
    assert_cycle([{'NULL' => nil}])
  end

  def test_insert_fixture
    payload_values = [{"val1" => "val2"}, {"val3_with_'_multiple" => "qu'ote_'_chars"}]
    @connection.insert_fixture({"payload" => payload_values}, "pg_hstore_arrays" )
    assert_equal(PgHstoreArray.last.payload, payload_values)
  end

  private
  def assert_cycle array
    # test creation
    x = PgHstoreArray.create!(payload: array)
    x.reload
    assert_equal(array, x.payload)

    # test updating
    x = PgHstoreArray.create!(payload: [])
    x.payload = array
    x.save!
    x.reload
    assert_equal(array, x.payload)
  end
end
