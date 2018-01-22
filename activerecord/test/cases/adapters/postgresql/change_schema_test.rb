# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class PGChangeSchemaTest < ActiveRecord::PostgreSQLTestCase
      attr_reader :connection

      def setup
        super
        @connection = ActiveRecord::Base.connection
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

      def test_change_type_with_array
        connection.change_column :strings, :somedate, :timestamp, array: true, cast_as: :timestamp
        column = connection.columns(:strings).find { |c| c.name == "somedate" }
        assert_equal :datetime, column.type
        assert column.array?
      end

      def test_create_enum
        connection.create_enum "my_enum", ["value1", "value2"]
        assert_includes connection.enums, "my_enum"
        assert_equal connection.enum_values("my_enum"), ["value1", "value2"]
      end

      def test_drop_enum
        connection.create_enum "my_enum", ["value1", "value2"]
        assert connection.enum_exists?("my_enum")

        connection.drop_enum "my_enum"
        assert_not connection.enum_exists?("my_enum")
      end

      def test_add_enum_value
        connection.create_enum "my_enum", ["value1", "value2"]
        assert_equal connection.enum_values("my_enum"), ["value1", "value2"]

        connection.add_enum_value "my_enum", "value3"
        assert_equal connection.enum_values("my_enum"), ["value1", "value2", "value3"]
      end

      def test_add_enum_value_with_before
        connection.create_enum "my_enum", ["value1", "value2"]
        assert_equal connection.enum_values("my_enum"), ["value1", "value2"]

        connection.add_enum_value "my_enum", "value0", before: "value1"
        assert_equal connection.enum_values("my_enum"), ["value0", "value1", "value2"]
      end

      def test_add_enum_value_with_after
        connection.create_enum "my_enum", ["value1", "value2"]
        assert_equal connection.enum_values("my_enum"), ["value1", "value2"]

        connection.add_enum_value "my_enum", "value1.5", after: "value1"
        assert_equal connection.enum_values("my_enum"), ["value1", "value1.5", "value2"]
      end
    end
  end
end
