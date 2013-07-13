# encoding: utf-8
require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlIntegerArrayTest < ActiveRecord::TestCase
  class PgIntegerArray < ActiveRecord::Base
    self.table_name = 'pg_integer_arrays'
  end

  def setup
    @connection = ActiveRecord::Base.connection
      @connection.transaction do
        @connection.create_table('pg_integer_arrays') do |t|
          t.integer 'tag_ids', :array => true
        end
      end
    @column = PgIntegerArray.columns.find { |c| c.name == 'tag_ids' }
  end

  def teardown
    @connection.execute 'drop table if exists pg_integer_arrays'
  end

  def test_column
    assert_equal :integer, @column.type
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
    assert_equal([1, 2, 3], array)
    assert_equal([1, 2, 3], @column.type_cast(data))

    assert_equal([], @column.type_cast('{}'))
    assert_equal([nil], @column.type_cast('{NULL}'))

    assert_equal([[1, 2, 3], [4]], @column.type_cast('{{1,2,3},{4}}'))
  end

  def test_rewrite
    @connection.execute "insert into pg_integer_arrays (tag_ids) VALUES ('{1,2,3}')"
    x = PgIntegerArray.first
    x.tag_ids = [1,2,3,4]
    assert x.save!
  end

  def test_select
    @connection.execute "insert into pg_integer_arrays (tag_ids) VALUES ('{1,2,3}')"
    x = PgIntegerArray.first
    assert_equal([1,2,3], x.tag_ids)
  end

  def test_multi_dimensional
    assert_cycle([[1,2],[2,3]])
  end

  def test_contains_nils
    assert_cycle([1,nil,nil])
  end

  def test_contains_strings
    assert_cycle([1,'2',3], [1,2,3])
  end

  def test_insert_fixture
    tag_values = [1,2,3,4,5]
    @connection.insert_fixture({"tag_ids" => tag_values}, "pg_integer_arrays" )
    assert_equal(PgIntegerArray.last.tag_ids, tag_values)
  end

  private
  def assert_cycle array, expected = array
    # test creation
    x = PgIntegerArray.create!(:tag_ids => array)
    x.reload
    assert_equal(expected, x.tag_ids)
    # test updating
    x = PgIntegerArray.create!(:tag_ids => [])
    x.tag_ids = array
    x.save!
    x.reload
    assert_equal(expected, x.tag_ids)
  end
end
