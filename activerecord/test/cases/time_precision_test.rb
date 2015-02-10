require 'cases/helper'

if ActiveRecord::Base.connection.supports_datetime_with_precision?
class TimePrecisionTest < ActiveRecord::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
  end

  teardown do
    @connection.drop_table :foos, if_exists: true
  end

  def test_time_data_type_with_precision
    @connection.create_table(:foos, force: true)
    @connection.add_column :foos, :start,  :time, precision: 3
    @connection.add_column :foos, :finish, :time, precision: 6
    assert_equal 3, activerecord_column_option('foos', 'start',  'precision')
    assert_equal 6, activerecord_column_option('foos', 'finish', 'precision')
  end

  def test_passing_precision_to_time_does_not_set_limit
    @connection.create_table(:foos, force: true) do |t|
      t.time :start,  precision: 3
      t.time :finish, precision: 6
    end
    assert_nil activerecord_column_option('foos', 'start',  'limit')
    assert_nil activerecord_column_option('foos', 'finish', 'limit')
  end

  def test_invalid_time_precision_raises_error
    assert_raises ActiveRecord::ActiveRecordError do
      @connection.create_table(:foos, force: true) do |t|
        t.time :start,  precision: 7
        t.time :finish, precision: 7
      end
    end
  end

  def test_database_agrees_with_activerecord_about_precision
    @connection.create_table(:foos, force: true) do |t|
      t.time :start,  precision: 2
      t.time :finish, precision: 4
    end
    assert_equal 2, database_datetime_precision('foos', 'start')
    assert_equal 4, database_datetime_precision('foos', 'finish')
  end

  private

  def database_datetime_precision(table_name, column_name)
    results = @connection.exec_query("SELECT column_name, datetime_precision FROM information_schema.columns WHERE table_name = '#{table_name}'")
    result = results.find do |result_hash|
      result_hash["column_name"] == column_name
    end
    result && result["datetime_precision"].to_i
  end

  def activerecord_column_option(tablename, column_name, option)
    result = @connection.columns(tablename).find do |column|
      column.name == column_name
    end
    result && result.send(option)
  end
end
end
