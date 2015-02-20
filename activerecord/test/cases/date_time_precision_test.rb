require 'cases/helper'
require 'support/schema_dumping_helper'

if ActiveRecord::Base.connection.supports_datetime_with_precision?
class DateTimePrecisionTest < ActiveRecord::TestCase
  include SchemaDumpingHelper
  self.use_transactional_fixtures = false

  class Foo < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
  end

  teardown do
    @connection.drop_table :foos, if_exists: true
  end

  def test_datetime_data_type_with_precision
    @connection.create_table(:foos, force: true)
    @connection.add_column :foos, :created_at, :datetime, precision: 0
    @connection.add_column :foos, :updated_at, :datetime, precision: 5
    assert_equal 0, activerecord_column_option('foos', 'created_at', 'precision')
    assert_equal 5, activerecord_column_option('foos', 'updated_at', 'precision')
  end

  def test_timestamps_helper_with_custom_precision
    @connection.create_table(:foos, force: true) do |t|
      t.timestamps precision: 4
    end
    assert_equal 4, activerecord_column_option('foos', 'created_at', 'precision')
    assert_equal 4, activerecord_column_option('foos', 'updated_at', 'precision')
  end

  def test_passing_precision_to_datetime_does_not_set_limit
    @connection.create_table(:foos, force: true) do |t|
      t.timestamps precision: 4
    end
    assert_nil activerecord_column_option('foos', 'created_at', 'limit')
    assert_nil activerecord_column_option('foos', 'updated_at', 'limit')
  end

  def test_invalid_datetime_precision_raises_error
    assert_raises ActiveRecord::ActiveRecordError do
      @connection.create_table(:foos, force: true) do |t|
        t.timestamps precision: 7
      end
    end
  end

  def test_database_agrees_with_activerecord_about_precision
    @connection.create_table(:foos, force: true) do |t|
      t.timestamps precision: 4
    end
    assert_equal 4, database_datetime_precision('foos', 'created_at')
    assert_equal 4, database_datetime_precision('foos', 'updated_at')
  end

  def test_formatting_datetime_according_to_precision
    @connection.create_table(:foos, force: true) do |t|
      t.datetime :created_at, precision: 0
      t.datetime :updated_at, precision: 4
    end
    date = ::Time.utc(2014, 8, 17, 12, 30, 0, 999999)
    Foo.create!(created_at: date, updated_at: date)
    assert foo = Foo.find_by(created_at: date)
    assert_equal 1, Foo.where(updated_at: date).count
    assert_equal date.to_s, foo.created_at.to_s
    assert_equal date.to_s, foo.updated_at.to_s
    assert_equal 000000, foo.created_at.usec
    assert_equal 999900, foo.updated_at.usec
  end

  def test_schema_dump_includes_datetime_precision
    @connection.create_table(:foos, force: true) do |t|
      t.timestamps precision: 6
    end
    output = dump_table_schema("foos")
    assert_match %r{t\.datetime\s+"created_at",\s+precision: 6,\s+null: false$}, output
    assert_match %r{t\.datetime\s+"updated_at",\s+precision: 6,\s+null: false$}, output
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_datetime_precision_with_zero_should_be_dumped
      @connection.create_table(:foos, force: true) do |t|
        t.timestamps precision: 0
      end
      output = dump_table_schema("foos")
      assert_match %r{t\.datetime\s+"created_at",\s+precision: 0,\s+null: false$}, output
      assert_match %r{t\.datetime\s+"updated_at",\s+precision: 0,\s+null: false$}, output
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
