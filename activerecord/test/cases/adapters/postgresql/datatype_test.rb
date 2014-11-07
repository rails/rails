require "cases/helper"
require 'support/ddl_helper'


class PostgresqlNumber < ActiveRecord::Base
end

class PostgresqlTime < ActiveRecord::Base
end

class PostgresqlOid < ActiveRecord::Base
end

class PostgresqlLtree < ActiveRecord::Base
end

class PostgresqlDataTypeTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  def setup
    @connection = ActiveRecord::Base.connection

    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (1, 123.456, 123456.789)")
    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (2, '-Infinity', 'Infinity')")
    @connection.execute("INSERT INTO postgresql_numbers (id, single, double) VALUES (3, 123.456, 'NaN')")
    @first_number = PostgresqlNumber.find(1)
    @second_number = PostgresqlNumber.find(2)
    @third_number = PostgresqlNumber.find(3)

    @connection.execute("INSERT INTO postgresql_times (id, time_interval, scaled_time_interval) VALUES (1, '1 year 2 days ago', '3 weeks ago')")
    @first_time = PostgresqlTime.find(1)

    @connection.execute("INSERT INTO postgresql_oids (id, obj_id) VALUES (1, 1234)")
    @first_oid = PostgresqlOid.find(1)
  end

  teardown do
    [PostgresqlNumber, PostgresqlTime, PostgresqlOid].each(&:delete_all)
  end

  def test_data_type_of_number_types
    assert_equal :float, @first_number.column_for_attribute(:single).type
    assert_equal :float, @first_number.column_for_attribute(:double).type
  end

  def test_data_type_of_time_types
    assert_equal :string, @first_time.column_for_attribute(:time_interval).type
    assert_equal :string, @first_time.column_for_attribute(:scaled_time_interval).type
  end

  def test_data_type_of_oid_types
    assert_equal :integer, @first_oid.column_for_attribute(:obj_id).type
  end

  def test_number_values
    assert_equal 123.456, @first_number.single
    assert_equal 123456.789, @first_number.double
    assert_equal(-::Float::INFINITY, @second_number.single)
    assert_equal ::Float::INFINITY, @second_number.double
    assert_same ::Float::NAN, @third_number.double
  end

  def test_time_values
    assert_equal '-1 years -2 days', @first_time.time_interval
    assert_equal '-21 days', @first_time.scaled_time_interval
  end

  def test_oid_values
    assert_equal 1234, @first_oid.obj_id
  end

  def test_update_number
    new_single = 789.012
    new_double = 789012.345
    @first_number.single = new_single
    @first_number.double = new_double
    assert @first_number.save
    assert @first_number.reload
    assert_equal new_single, @first_number.single
    assert_equal new_double, @first_number.double
  end

  def test_update_time
    @first_time.time_interval = '2 years 3 minutes'
    assert @first_time.save
    assert @first_time.reload
    assert_equal '2 years 00:03:00', @first_time.time_interval
  end

  def test_update_oid
    new_value = 567890
    @first_oid.obj_id = new_value
    assert @first_oid.save
    assert @first_oid.reload
    assert_equal new_value, @first_oid.obj_id
  end

  def test_text_columns_are_limitless_the_upper_limit_is_one_GB
    assert_equal 'text', @connection.type_to_sql(:text, 100_000)
    assert_raise ActiveRecord::ActiveRecordError do
      @connection.type_to_sql :text, 4294967295
    end
  end
end

class PostgresqlInternalDataTypeTest < ActiveRecord::TestCase
  include DdlHelper

  setup do
    @connection = ActiveRecord::Base.connection
  end

  def test_name_column_type
    with_example_table @connection, 'ex', 'data name' do
      column = @connection.columns('ex').find { |col| col.name == 'data' }
      assert_equal :string, column.type
    end
  end

  def test_char_column_type
    with_example_table @connection, 'ex', 'data "char"' do
      column = @connection.columns('ex').find { |col| col.name == 'data' }
      assert_equal :string, column.type
    end
  end
end
