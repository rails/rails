# encoding: utf-8
require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlStringArrayTest < ActiveRecord::TestCase
  class PgStringArray < ActiveRecord::Base
    self.table_name = 'pg_string_arrays'
  end

  def setup
    @connection = ActiveRecord::Base.connection
      @connection.transaction do
        @connection.create_table('pg_string_arrays') do |t|
          t.string 'tags', :array => true
        end
      end
    @column = PgStringArray.columns.find { |c| c.name == 'tags' }
  end

  def teardown
    @connection.execute 'drop table if exists pg_string_arrays'
  end

  def test_column
    assert_equal :string, @column.type
    assert @column.array
  end

  def test_type_cast_array
    assert @column

    data = '{1,2,3}'
    oid_type  = @column.instance_variable_get('@oid_type').subtype
    # we are getting the instance variable in this test, but in the
    # normal use of string_to_array, it's called from the OID::Array
    # class and will have the OID instance that will provide the type
    # casting
    array = @column.class.string_to_array data, oid_type
    assert_equal(['1', '2', '3'], array)
    assert_equal(['1', '2', '3'], @column.type_cast(data))

    assert_equal([], @column.type_cast('{}'))
    assert_equal([nil], @column.type_cast('{NULL}'))

    assert_equal([['1', '2', '3'], ['4']], @column.type_cast('{{1,2,3},{4}}'))
  end

  def test_rewrite
    @connection.execute "insert into pg_string_arrays (tags) VALUES ('{1,2,3}')"
    x = PgStringArray.first
    x.tags = ['1','2','3','4']
    assert x.save!
  end

  def test_select
    @connection.execute "insert into pg_string_arrays (tags) VALUES ('{1,2,3}')"
    x = PgStringArray.first
    assert_equal(['1','2','3'], x.tags)
  end

  def test_multi_dimensional
    assert_cycle([['1','2'],['2','3']])
  end

  def test_strings_with_quotes
    assert_cycle(['this has','some "s that need to be escaped"'])
  end

  def test_strings_with_commas
    assert_cycle(['this,has','many,values'])
  end

  def test_strings_with_array_delimiters
    assert_cycle(['{','}'])
  end

  def test_strings_with_null_strings
    assert_cycle(['NULL','NULL'])
  end

  def test_contains_nils
    assert_cycle(['1',nil,nil])
  end

  def test_insert_fixture
    tag_values = ["val1", "val2", "val3_with_'_multiple_quote_'_chars"]
    @connection.insert_fixture({"tags" => tag_values}, "pg_string_arrays" )
    assert_equal(PgStringArray.last.tags, tag_values)
  end

  private
  def assert_cycle array
    # test creation
    x = PgStringArray.create!(:tags => array)
    x.reload
    assert_equal(array, x.tags)

    # test updating
    x = PgStringArray.create!(:tags => [])
    x.tags = array
    x.save!
    x.reload
    assert_equal(array, x.tags)
  end
end
