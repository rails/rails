require 'cases/helper'
require 'support/schema_dumping_helper'

if ActiveRecord::Base.connection.supports_datetime_with_precision?
class TimePrecisionTest < ActiveRecord::TestCase
  include SchemaDumpingHelper
  self.use_transactional_fixtures = false

  class Foo < ActiveRecord::Base; end

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

  def test_formatting_time_according_to_precision
    @connection.create_table(:foos, force: true) do |t|
      t.time :start,  precision: 0
      t.time :finish, precision: 4
    end
    time = ::Time.utc(2000, 1, 1, 12, 30, 0, 999999)
    Foo.create!(start: time, finish: time)
    assert foo = Foo.find_by(start: time)
    assert_equal 1, Foo.where(finish: time).count
    assert_equal time.to_s, foo.start.to_s
    assert_equal time.to_s, foo.finish.to_s
    assert_equal 000000, foo.start.usec
    assert_equal 999900, foo.finish.usec
  end

  def test_schema_dump_includes_time_precision
    @connection.create_table(:foos, force: true) do |t|
      t.time :start,  precision: 4
      t.time :finish, precision: 6
    end
    output = dump_table_schema("foos")
    assert_match %r{t\.time\s+"start",\s+precision: 4$}, output
    assert_match %r{t\.time\s+"finish",\s+precision: 6$}, output
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_time_precision_with_zero_should_be_dumped
      @connection.create_table(:foos, force: true) do |t|
        t.time :start,  precision: 0
        t.time :finish, precision: 0
      end
      output = dump_table_schema("foos")
      assert_match %r{t\.time\s+"start",\s+precision: 0$}, output
      assert_match %r{t\.time\s+"finish",\s+precision: 0$}, output
    end
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
