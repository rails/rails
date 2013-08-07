# encoding: utf-8
require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlArrayTest < ActiveRecord::TestCase
  class PgArray < ActiveRecord::Base
    self.table_name = 'pg_arrays'
  end

  def setup
    @connection = ActiveRecord::Base.connection
      @connection.transaction do
        @connection.create_table('pg_arrays') do |t|
          t.string 'tags', array: true
          t.integer 'ratings', array: true
        end
      end
    @column = PgArray.columns.find { |c| c.name == 'tags' }
  end

  def teardown
    @connection.execute 'drop table if exists pg_arrays'
  end

  def test_column
    assert_equal :string, @column.type
    assert @column.array
  end

  def test_change_column_with_array
    @connection.add_column :pg_arrays, :snippets, :string, array: true, default: []
    @connection.change_column :pg_arrays, :snippets, :text, array: true, default: "{}"

    PgArray.reset_column_information
    column = PgArray.columns.find { |c| c.name == 'snippets' }

    assert_equal :text, column.type
    assert_equal [], column.default
    assert column.array
  end

  def test_change_column_cant_make_non_array_column_to_array
    @connection.add_column :pg_arrays, :a_string, :string
    assert_raises ActiveRecord::StatementInvalid do
      @connection.transaction do
        @connection.change_column :pg_arrays, :a_string, :string, array: true
      end
    end
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
  end

  def test_rewrite
    @connection.execute "insert into pg_arrays (tags) VALUES ('{1,2,3}')"
    x = PgArray.first
    x.tags = ['1','2','3','4']
    assert x.save!
  end

  def test_select
    @connection.execute "insert into pg_arrays (tags) VALUES ('{1,2,3}')"
    x = PgArray.first
    assert_equal(['1','2','3'], x.tags)
  end

  def test_multi_dimensional_with_strings
    assert_cycle(:tags, [[['1'], ['2']], [['2'], ['3']]])
  end

  def test_multi_dimensional_with_integers
    assert_cycle(:ratings, [[[1], [7]], [[8], [10]]])
  end

  def test_strings_with_quotes
    assert_cycle(:tags, ['this has','some "s that need to be escaped"'])
  end

  def test_strings_with_commas
    assert_cycle(:tags, ['this,has','many,values'])
  end

  def test_strings_with_array_delimiters
    assert_cycle(:tags, ['{','}'])
  end

  def test_strings_with_null_strings
    assert_cycle(:tags, ['NULL','NULL'])
  end

  def test_contains_nils
    assert_cycle(:tags, ['1',nil,nil])
  end

  def test_insert_fixture
    tag_values = ["val1", "val2", "val3_with_'_multiple_quote_'_chars"]
    @connection.insert_fixture({"tags" => tag_values}, "pg_arrays" )
    assert_equal(PgArray.last.tags, tag_values)
  end

  private
  def assert_cycle field, array
    # test creation
    x = PgArray.create!(field => array)
    x.reload
    assert_equal(array, x.public_send(field))

    # test updating
    x = PgArray.create!(field => [])
    x.public_send("#{field}=", array)
    x.save!
    x.reload
    assert_equal(array, x.public_send(field))
  end
end
