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
    end
  end
end
