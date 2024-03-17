# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class PGChangeSchemaTest < ActiveRecord::PostgreSQLTestCase
      attr_reader :connection

      def setup
        super
        @connection = ActiveRecord::Base.lease_connection
        connection.create_table(:strings) do |t|
          t.string :somedate
        end
      end

      def teardown
        connection.drop_table :strings
      end

      def test_change_string_to_date
        connection.change_column :strings, :somedate, :timestamp, using: 'CAST("somedate" AS timestamp)'
        assert_equal :datetime, connection.columns(:strings).find { |c| c.name == "somedate" }.type
      end

      def test_change_type_with_symbol
        connection.change_column :strings, :somedate, :timestamp, cast_as: :timestamp
        assert_equal :datetime, connection.columns(:strings).find { |c| c.name == "somedate" }.type
      end

      def test_change_type_with_symbol_with_timestamptz
        connection.change_column :strings, :somedate, :timestamptz, cast_as: :timestamptz
        assert_equal :timestamptz, connection.columns(:strings).find { |c| c.name == "somedate" }.type
      end

      def test_change_type_with_symbol_using_datetime
        connection.change_column :strings, :somedate, :datetime, cast_as: :datetime
        assert_equal :datetime, connection.columns(:strings).find { |c| c.name == "somedate" }.type
      end

      def test_change_type_with_symbol_using_timestamp_with_timestamptz_as_default
        with_postgresql_datetime_type(:timestamptz) do
          connection.change_column :strings, :somedate, :timestamp, cast_as: :timestamp
          assert_equal :timestamp, connection.columns(:strings).find { |c| c.name == "somedate" }.type
        end
      end

      def test_change_type_with_symbol_with_timestamptz_as_default
        with_postgresql_datetime_type(:timestamptz) do
          connection.change_column :strings, :somedate, :timestamptz, cast_as: :timestamptz
          assert_equal :datetime, connection.columns(:strings).find { |c| c.name == "somedate" }.type
        end
      end

      def test_change_type_with_symbol_using_datetime_with_timestamptz_as_default
        with_postgresql_datetime_type(:timestamptz) do
          connection.change_column :strings, :somedate, :datetime, cast_as: :datetime
          assert_equal :datetime, connection.columns(:strings).find { |c| c.name == "somedate" }.type
        end
      end

      def test_change_type_with_array
        connection.change_column :strings, :somedate, :timestamp, array: true, cast_as: :timestamp
        column = connection.columns(:strings).find { |c| c.name == "somedate" }
        assert_equal :datetime, column.type
        assert_predicate column, :array?
      end
    end
  end
end
