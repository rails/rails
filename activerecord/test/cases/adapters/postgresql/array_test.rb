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
        t.datetime :datetimes, array: true
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
    assert_not @column.text?

    ratings_column = PgArray.columns_hash['ratings']
    assert_equal :integer, ratings_column.type
    assert ratings_column.array
    assert_not ratings_column.number?
  end

  def test_default
    @connection.add_column 'pg_arrays', 'score', :integer, array: true, default: [4, 4, 2]
    PgArray.reset_column_information
    column = PgArray.columns_hash["score"]

    assert_equal([4, 4, 2], column.default)
    assert_equal([4, 4, 2], PgArray.new.score)
  ensure
    PgArray.reset_column_information
  end

  def test_default_strings
    @connection.add_column 'pg_arrays', 'names', :string, array: true, default: ["foo", "bar"]
    PgArray.reset_column_information
    column = PgArray.columns_hash["names"]

    assert_equal(["foo", "bar"], column.default)
    assert_equal(["foo", "bar"], PgArray.new.names)
  ensure
    PgArray.reset_column_information
  end

  def test_change_column_with_array
    @connection.add_column :pg_arrays, :snippets, :string, array: true, default: []
    @connection.change_column :pg_arrays, :snippets, :text, array: true, default: []

    PgArray.reset_column_information
    column = PgArray.columns.find { |c| c.name == 'snippets' }

    assert_equal :text, column.type
    assert_equal [], column.default
    assert column.array
  end

  def test_change_column_default_with_array
    @connection.change_column_default :pg_arrays, :tags, []

    PgArray.reset_column_information
    column = PgArray.columns_hash['tags']
    assert_equal [], column.default
  end

  def test_type_cast_array
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

  def test_type_cast_integers
    x = PgArray.new(ratings: ['1', '2'])
    assert x.save!
    assert_equal(['1', '2'], x.ratings)
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
    assert_cycle([[['1'], ['2']], [['2'], ['3']]])
  end

  def test_with_empty_strings
    assert_cycle([ '1', '2', '', '4', '', '5' ])
  end

  def test_with_multi_dimensional_empty_strings
    assert_cycle([[['1', '2'], ['', '4'], ['', '5']]])
  end

  def test_with_arbitrary_whitespace
    assert_cycle([[['1', '2'], ['    ', '4'], ['    ', '5']]])
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
    @connection.insert_fixture({"tags" => tag_values}, "pg_arrays" )
    assert_equal(PgArray.last.tags, tag_values)
  end

  def test_update_all
    pg_array = PgArray.create! tags: ["one", "two", "three"]

    PgArray.update_all tags: ["four", "five"]
    assert_equal ["four", "five"], pg_array.reload.tags

    PgArray.update_all tags: []
    assert_equal [], pg_array.reload.tags
  end

  def test_datetime_with_timezone_awareness
    old_awareness = ActiveRecord::Base.time_zone_aware_attributes
    ActiveRecord::Base.time_zone_aware_attributes = true

    old_zone  = Time.zone
    Time.zone = ActiveSupport::TimeZone["Pacific Time (US & Canada)"]

    PgArray.reset_column_information
    time_string = Time.current.to_s
    time = Time.zone.parse(time_string)

    record = PgArray.new(datetimes: [time_string])
    assert_equal [time], record.datetimes

    record.save!
    record.reload

    assert_equal [time], record.datetimes
  ensure
    Time.zone = old_zone
    ActiveRecord::Base.time_zone_aware_attributes = old_awareness
  end

  private

  def assert_cycle(array)
    # test creation
    x = PgArray.create!(tags: array)
    x.reload
    assert_equal(array, x.tags)

    # test updating
    x = PgArray.create!(tags: [])
    x.tags = array
    x.save!
    x.reload
    assert_equal(array, x.tags)
  end
end
