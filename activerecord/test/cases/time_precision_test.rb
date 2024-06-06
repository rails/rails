# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class TimePrecisionTest < ActiveRecord::TestCase
  if supports_datetime_with_precision?
    include SchemaDumpingHelper
    self.use_transactional_tests = false

    class Foo < ActiveRecord::Base; end

    setup do
      @connection = ActiveRecord::Base.lease_connection
      Foo.reset_column_information
    end

    teardown do
      @connection.drop_table :foos, if_exists: true
    end

    def test_time_data_type_with_precision
      @connection.create_table(:foos, force: true)
      @connection.add_column :foos, :start,  :time, precision: 3
      @connection.add_column :foos, :finish, :time, precision: 6
      assert_equal 3, Foo.columns_hash["start"].precision
      assert_equal 6, Foo.columns_hash["finish"].precision
    end

    def test_time_precision_is_truncated_on_assignment
      @connection.create_table(:foos, force: true)
      @connection.add_column :foos, :start,  :time, precision: 0
      @connection.add_column :foos, :finish, :time, precision: 6

      time = ::Time.now.change(nsec: 123456789)
      foo = Foo.new(start: time, finish: time)

      assert_equal 0, foo.start.nsec
      assert_equal 123456000, foo.finish.nsec

      foo.save!
      foo.reload

      assert_equal 0, foo.start.nsec
      assert_equal 123456000, foo.finish.nsec
    end

    unless current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      def test_no_time_precision_isnt_truncated_on_assignment
        @connection.create_table(:foos, force: true)
        @connection.add_column :foos, :start,  :time
        @connection.add_column :foos, :finish, :time, precision: 6

        time = ::Time.now.change(nsec: 123)
        foo = Foo.new(start: time, finish: time)

        assert_equal 123, foo.start.nsec
        assert_equal 0, foo.finish.nsec

        foo.save!
        foo.reload

        assert_equal 0, foo.start.nsec
        assert_equal 0, foo.finish.nsec
      end
    end

    def test_passing_precision_to_time_does_not_set_limit
      @connection.create_table(:foos, force: true) do |t|
        t.time :start,  precision: 3
        t.time :finish, precision: 6
      end
      assert_nil Foo.columns_hash["start"].limit
      assert_nil Foo.columns_hash["finish"].limit
    end

    def test_invalid_time_precision_raises_error
      assert_raises ArgumentError do
        @connection.create_table(:foos, force: true) do |t|
          t.time :start,  precision: 7
          t.time :finish, precision: 7
        end
      end
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
  end
end
