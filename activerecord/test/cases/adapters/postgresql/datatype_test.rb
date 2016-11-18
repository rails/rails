require "cases/helper"
require "support/ddl_helper"

class PostgresqlTime < ActiveRecord::Base
end

class PostgresqlOid < ActiveRecord::Base
end

class PostgresqlLtree < ActiveRecord::Base
end

class PostgresqlDataTypeTest < ActiveRecord::PostgreSQLTestCase
  self.use_transactional_tests = false

  def setup
    @connection = ActiveRecord::Base.connection

    @connection.execute("INSERT INTO postgresql_times (id, time_interval, scaled_time_interval) VALUES (1, '1 year 2 days ago', '3 weeks ago')")
    @first_time = PostgresqlTime.find(1)

    @connection.execute("INSERT INTO postgresql_oids (id, obj_id) VALUES (1, 1234)")
    @first_oid = PostgresqlOid.find(1)
  end

  teardown do
    [PostgresqlTime, PostgresqlOid].each(&:delete_all)
  end

  def test_data_type_of_time_types
    assert_equal :string, @first_time.column_for_attribute(:time_interval).type
    assert_equal :string, @first_time.column_for_attribute(:scaled_time_interval).type
  end

  def test_data_type_of_oid_types
    assert_equal :integer, @first_oid.column_for_attribute(:obj_id).type
  end

  def test_time_values
    assert_equal "-1 years -2 days", @first_time.time_interval
    assert_equal "-21 days", @first_time.scaled_time_interval
  end

  def test_oid_values
    assert_equal 1234, @first_oid.obj_id
  end

  def test_update_time
    @first_time.time_interval = "2 years 3 minutes"
    assert @first_time.save
    assert @first_time.reload
    assert_equal "2 years 00:03:00", @first_time.time_interval
  end

  def test_update_oid
    new_value = 567890
    @first_oid.obj_id = new_value
    assert @first_oid.save
    assert @first_oid.reload
    assert_equal new_value, @first_oid.obj_id
  end

  def test_text_columns_are_limitless_the_upper_limit_is_one_GB
    assert_equal "text", @connection.type_to_sql(:text, 100_000)
    assert_raise ActiveRecord::ActiveRecordError do
      @connection.type_to_sql :text, 4294967295
    end
  end
end

class PostgresqlInternalDataTypeTest < ActiveRecord::PostgreSQLTestCase
  include DdlHelper

  setup do
    @connection = ActiveRecord::Base.connection
  end

  def test_name_column_type
    with_example_table @connection, "ex", "data name" do
      column = @connection.columns("ex").find { |col| col.name == "data" }
      assert_equal :string, column.type
    end
  end

  def test_char_column_type
    with_example_table @connection, "ex", 'data "char"' do
      column = @connection.columns("ex").find { |col| col.name == "data" }
      assert_equal :string, column.type
    end
  end
end
