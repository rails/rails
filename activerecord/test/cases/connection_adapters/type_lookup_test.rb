require "cases/helper"

unless current_adapter?(:PostgreSQLAdapter) # PostgreSQL does not use type strigns for lookup
module ActiveRecord
  module ConnectionAdapters
    class TypeLookupTest < ActiveRecord::TestCase
      setup do
        @connection = ActiveRecord::Base.connection
      end

      def test_boolean_types
        assert_lookup_type :boolean, 'boolean'
        assert_lookup_type :boolean, 'BOOLEAN'
      end

      def test_string_types
        assert_lookup_type :string, 'char'
        assert_lookup_type :string, 'varchar'
        assert_lookup_type :string, 'VARCHAR'
        assert_lookup_type :string, 'varchar(255)'
        assert_lookup_type :string, 'character varying'
      end

      def test_binary_types
        assert_lookup_type :binary, 'binary'
        assert_lookup_type :binary, 'BINARY'
        assert_lookup_type :binary, 'blob'
        assert_lookup_type :binary, 'BLOB'
      end

      def test_text_types
        assert_lookup_type :text, 'text'
        assert_lookup_type :text, 'TEXT'
        assert_lookup_type :text, 'clob'
        assert_lookup_type :text, 'CLOB'
      end

      def test_date_types
        assert_lookup_type :date, 'date'
        assert_lookup_type :date, 'DATE'
      end

      def test_time_types
        assert_lookup_type :time, 'time'
        assert_lookup_type :time, 'TIME'
      end

      def test_timestamp_types
        assert_lookup_type :timestamp, 'timestamp'
        assert_lookup_type :timestamp, 'TIMESTAMP'
      end

      def test_datetime_types
        assert_lookup_type :datetime, 'datetime'
        assert_lookup_type :datetime, 'DATETIME'
      end

      def test_decimal_types
        assert_lookup_type :decimal, 'decimal'
        assert_lookup_type :decimal, 'decimal(2,8)'
        assert_lookup_type :decimal, 'DECIMAL'
        assert_lookup_type :decimal, 'numeric'
        assert_lookup_type :decimal, 'numeric(2,8)'
        assert_lookup_type :decimal, 'NUMERIC'
        assert_lookup_type :decimal, 'number'
        assert_lookup_type :decimal, 'number(2,8)'
        assert_lookup_type :decimal, 'NUMBER'
      end

      def test_float_types
        assert_lookup_type :float, 'float'
        assert_lookup_type :float, 'FLOAT'
        assert_lookup_type :float, 'double'
        assert_lookup_type :float, 'DOUBLE'
      end

      def test_integer_types
        assert_lookup_type :integer, 'integer'
        assert_lookup_type :integer, 'INTEGER'
        assert_lookup_type :integer, 'tinyint'
        assert_lookup_type :integer, 'smallint'
        assert_lookup_type :integer, 'bigint'
        assert_lookup_type :integer, 'decimal(2)'
        assert_lookup_type :integer, 'decimal(2,0)'
        assert_lookup_type :integer, 'numeric(2)'
        assert_lookup_type :integer, 'numeric(2,0)'
        assert_lookup_type :integer, 'number(2)'
        assert_lookup_type :integer, 'number(2,0)'
      end

      private

      def assert_lookup_type(type, lookup)
        cast_type = @connection.type_map.lookup(lookup)
        assert_equal type, cast_type.type
      end
    end
  end
end
end
