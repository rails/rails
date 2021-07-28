# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

if supports_datetime_with_precision?
  class DateTimePrecisionTest < ActiveRecord::TestCase
    include SchemaDumpingHelper
    self.use_transactional_tests = false

    class Foo < ActiveRecord::Base; end

    setup do
      @connection = ActiveRecord::Base.connection
      Foo.reset_column_information
    end

    teardown do
      @connection.drop_table :foos, if_exists: true
    end

    def test_datetime_data_type_with_precision
      @connection.create_table(:foos, force: true)
      @connection.add_column :foos, :created_at, :datetime, precision: 0
      @connection.add_column :foos, :updated_at, :datetime, precision: 5
      assert_equal 0, Foo.columns_hash["created_at"].precision
      assert_equal 5, Foo.columns_hash["updated_at"].precision
    end

    def test_datetime_precision_is_truncated_on_assignment
      @connection.create_table(:foos, force: true)
      @connection.add_column :foos, :created_at, :datetime, precision: 0
      @connection.add_column :foos, :updated_at, :datetime, precision: 6

      time = ::Time.now.change(nsec: 123456789)
      foo = Foo.new(created_at: time, updated_at: time)

      assert_equal 0, foo.created_at.nsec
      assert_equal 123456000, foo.updated_at.nsec

      foo.save!
      foo.reload

      assert_equal 0, foo.created_at.nsec
      assert_equal 123456000, foo.updated_at.nsec
    end

    unless current_adapter?(:Mysql2Adapter)
      def test_no_datetime_precision_isnt_truncated_on_assignment
        @connection.create_table(:foos, force: true)
        @connection.add_column :foos, :created_at, :datetime, precision: nil
        @connection.add_column :foos, :updated_at, :datetime

        time = ::Time.now.change(nsec: 123)
        foo = Foo.new(created_at: time, updated_at: time)

        assert_equal 123, foo.created_at.nsec
        assert_equal 0, foo.updated_at.nsec

        foo.save!
        foo.reload

        assert_equal 0, foo.created_at.nsec
        assert_equal 0, foo.updated_at.nsec
      end
    end

    def test_timestamps_helper_with_custom_precision
      @connection.create_table(:foos, force: true) do |t|
        t.timestamps precision: 4
      end
      assert_equal 4, Foo.columns_hash["created_at"].precision
      assert_equal 4, Foo.columns_hash["updated_at"].precision
    end

    def test_passing_precision_to_datetime_does_not_set_limit
      @connection.create_table(:foos, force: true) do |t|
        t.timestamps precision: 4
      end
      assert_nil Foo.columns_hash["created_at"].limit
      assert_nil Foo.columns_hash["updated_at"].limit
    end

    def test_invalid_datetime_precision_raises_error
      assert_raises ArgumentError do
        @connection.create_table(:foos, force: true) do |t|
          t.timestamps precision: 7
        end
      end
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
      assert_equal date.to_i, foo.created_at.to_i
      assert_equal date.to_s, foo.created_at.to_s
      assert_equal date.to_s, foo.updated_at.to_s
      assert_equal 000000, foo.created_at.usec
      assert_equal 999900, foo.updated_at.usec
    end

    def test_formatting_datetime_according_to_precision_when_time_zone_aware
      with_timezone_config aware_attributes: true, zone: "Pacific Time (US & Canada)" do
        @connection.create_table(:foos, force: true) do |t|
          t.datetime :created_at, precision: 0
          t.datetime :updated_at, precision: 4
        end

        date = ::Time.utc(2014, 8, 17, 12, 30, 0, 999999)
        Foo.create!(created_at: date, updated_at: date)

        assert foo = Foo.find_by(created_at: date)
        assert_equal 1, Foo.where(updated_at: date).count
        assert_equal date.to_i, foo.created_at.to_i
        assert_equal date.in_time_zone.to_s, foo.created_at.to_s
        assert_equal date.in_time_zone.to_s, foo.updated_at.to_s
        assert_equal 000000, foo.created_at.usec
        assert_equal 999900, foo.updated_at.usec
      end
    end

    if current_adapter?(:PostgreSQLAdapter)
      def test_formatting_datetime_according_to_precision_using_timestamptz
        with_postgresql_datetime_type(:timestamptz) do
          @connection.create_table(:foos, force: true) do |t|
            t.datetime :created_at, precision: 0
            t.datetime :updated_at, precision: 4
          end

          date = ::Time.utc(2014, 8, 17, 12, 30, 0, 999999)
          Foo.create!(created_at: date, updated_at: date)

          assert foo = Foo.find_by(created_at: date)
          assert_equal 1, Foo.where(updated_at: date).count
          assert_equal date.to_i, foo.created_at.to_i
          assert_equal date.to_s, foo.created_at.to_s
          assert_equal date.to_s, foo.updated_at.to_s
          assert_equal 000000, foo.created_at.usec
          assert_equal 999900, foo.updated_at.usec
        end
      end

      def test_formatting_datetime_according_to_precision_when_time_zone_aware_using_timestamptz
        with_postgresql_datetime_type(:timestamptz) do
          with_timezone_config aware_attributes: true, zone: "Pacific Time (US & Canada)" do
            @connection.create_table(:foos, force: true) do |t|
              t.datetime :created_at, precision: 0
              t.datetime :updated_at, precision: 4
            end

            date = ::Time.utc(2014, 8, 17, 12, 30, 0, 999999)
            Foo.create!(created_at: date, updated_at: date)

            assert foo = Foo.find_by(created_at: date)
            assert_equal 1, Foo.where(updated_at: date).count
            assert_equal date.to_i, foo.created_at.to_i
            assert_equal date.in_time_zone.to_s, foo.created_at.to_s
            assert_equal date.in_time_zone.to_s, foo.updated_at.to_s
            assert_equal 000000, foo.created_at.usec
            assert_equal 999900, foo.updated_at.usec
          end
        end
      end
    end

    def test_schema_dump_includes_datetime_precision
      @connection.create_table(:foos, force: true) do |t|
        t.timestamps precision: 6
      end
      output = dump_table_schema("foos")
      assert_match %r{t\.datetime\s+"created_at",\s+precision: 6,\s+null: false$}, output
      assert_match %r{t\.datetime\s+"updated_at",\s+precision: 6,\s+null: false$}, output
    end

    if current_adapter?(:PostgreSQLAdapter, :SQLServerAdapter)
      def test_datetime_precision_with_zero_should_be_dumped
        @connection.create_table(:foos, force: true) do |t|
          t.timestamps precision: 0
        end
        output = dump_table_schema("foos")
        assert_match %r{t\.datetime\s+"created_at",\s+precision: 0,\s+null: false$}, output
        assert_match %r{t\.datetime\s+"updated_at",\s+precision: 0,\s+null: false$}, output
      end
    end
  end
end
