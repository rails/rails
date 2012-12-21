# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlIntrangesTest < ActiveRecord::TestCase
  class IntRangeDataType < ActiveRecord::Base
    self.table_name = 'intrange_data_type'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('intrange_data_type') do |t|
          t.intrange 'int_range', :default => (1..10)
          t.intrange 'long_int_range', :limit => 8, :default => (1..100)
        end
      end
    rescue ActiveRecord::StatementInvalid
      return skip "do not test on PG without ranges"
    end
    @int_range_column = IntRangeDataType.columns.find { |c| c.name == 'int_range' }
    @long_int_range_column = IntRangeDataType.columns.find { |c| c.name == 'long_int_range' }
  end

  def teardown
    @connection.execute 'drop table if exists intrange_data_type'
  end

  def test_columns
    assert_equal :intrange, @int_range_column.type
    assert_equal :intrange, @long_int_range_column.type
  end

  def test_type_cast_intrange
    assert @int_range_column
    assert_equal(true, @int_range_column.has_default?)
    assert_equal((1..10), @int_range_column.default)
    assert_equal("int4range", @int_range_column.sql_type)

    data = "[1,10)"
    hash = @int_range_column.class.string_to_intrange data
    assert_equal((1..9), hash)
    assert_equal((1..9), @int_range_column.type_cast(data))

    assert_equal((nil..nil), @int_range_column.type_cast("empty"))
    assert_equal((1..5), @int_range_column.type_cast('[1,5]'))
    assert_equal((2..4), @int_range_column.type_cast('(1,5)'))
    assert_equal((2..39), @int_range_column.type_cast('[2,40)'))
    assert_equal((10..20), @int_range_column.type_cast('(9,20]'))
  end

  def test_type_cast_long_intrange
    assert @long_int_range_column
    assert_equal(true, @long_int_range_column.has_default?)
    assert_equal((1..100), @long_int_range_column.default)
    assert_equal("int8range", @long_int_range_column.sql_type)
  end

  def test_rewrite
    @connection.execute "insert into intrange_data_type (int_range) VALUES ('(1, 6)')"
    x = IntRangeDataType.first
    x.int_range = (1..100)
    assert x.save!
  end

  def test_select
    @connection.execute "insert into intrange_data_type (int_range) VALUES ('(1, 4]')"
    x = IntRangeDataType.first
    assert_equal((2..4), x.int_range)
  end

  def test_empty_range
    @connection.execute %q|insert into intrange_data_type (int_range) VALUES('empty')|
    x = IntRangeDataType.first
    assert_equal((nil..nil), x.int_range)
  end

  def test_rewrite_to_nil
    @connection.execute %q|insert into intrange_data_type (int_range) VALUES('(1, 4]')|
    x = IntRangeDataType.first
    x.int_range = nil
    assert x.save!
    assert_equal(nil, x.int_range)
  end

  def test_invalid_intrange
    assert IntRangeDataType.create!(int_range: ('a'..'d'))
    x = IntRangeDataType.first
    assert_equal(nil, x.int_range)
  end

  def test_save_empty_range
    assert IntRangeDataType.create!(int_range: (nil..nil))
    x = IntRangeDataType.first
    assert_equal((nil..nil), x.int_range)
  end

  def test_save_invalid_data
    assert_raises(ActiveRecord::StatementInvalid) do
      IntRangeDataType.create!(int_range: "empty1")
    end
  end
end
