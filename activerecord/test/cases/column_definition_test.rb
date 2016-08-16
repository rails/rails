require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ColumnDefinitionTest < ActiveRecord::TestCase
      def setup
        @adapter = AbstractAdapter.new(nil)
        def @adapter.native_database_types
          { string: "varchar" }
        end
        @viz = @adapter.schema_creation
      end

      # Avoid column definitions in create table statements like:
      # `title` varchar(255) DEFAULT NULL
      def test_should_not_include_default_clause_when_default_is_null
        column = Column.new("title", nil, SqlTypeMetadata.new(limit: 20))
        column_def = ColumnDefinition.new(
          column.name, "string",
          column.limit, column.precision, column.scale, column.default, column.null)
        assert_equal "title varchar(20)", @viz.accept(column_def)
      end

      def test_should_include_default_clause_when_default_is_present
        column = Column.new("title", "Hello", SqlTypeMetadata.new(limit: 20))
        column_def = ColumnDefinition.new(
          column.name, "string",
          column.limit, column.precision, column.scale, column.default, column.null)
        assert_equal "title varchar(20) DEFAULT 'Hello'", @viz.accept(column_def)
      end

      def test_should_specify_not_null_if_null_option_is_false
        type_metadata = SqlTypeMetadata.new(limit: 20)
        column = Column.new("title", "Hello", type_metadata, false)
        column_def = ColumnDefinition.new(
          column.name, "string",
          column.limit, column.precision, column.scale, column.default, column.null)
        assert_equal "title varchar(20) DEFAULT 'Hello' NOT NULL", @viz.accept(column_def)
      end

      if current_adapter?(:Mysql2Adapter)
        def test_should_set_default_for_mysql_binary_data_types
          type = SqlTypeMetadata.new(type: :binary, sql_type: "binary(1)")
          binary_column = MySQL::Column.new("title", "a", type)
          assert_equal "a", binary_column.default

          type = SqlTypeMetadata.new(type: :binary, sql_type: "varbinary")
          varbinary_column = MySQL::Column.new("title", "a", type)
          assert_equal "a", varbinary_column.default
        end

        def test_should_be_empty_string_default_for_mysql_binary_data_types
          type = SqlTypeMetadata.new(type: :binary, sql_type: "binary(1)")
          binary_column = MySQL::Column.new("title", "", type, false)
          assert_equal "", binary_column.default

          type = SqlTypeMetadata.new(type: :binary, sql_type: "varbinary")
          varbinary_column = MySQL::Column.new("title", "", type, false)
          assert_equal "", varbinary_column.default
        end

        def test_should_not_set_default_for_blob_and_text_data_types
          text_type = MySQL::TypeMetadata.new(
            SqlTypeMetadata.new(type: :text))

          text_column = MySQL::Column.new("title", nil, text_type)
          assert_equal nil, text_column.default

          not_null_text_column = MySQL::Column.new("title", nil, text_type, false)
          assert_equal "", not_null_text_column.default
        end

        def test_has_default_should_return_false_for_blob_and_text_data_types
          binary_type = SqlTypeMetadata.new(sql_type: "blob")
          blob_column = MySQL::Column.new("title", nil, binary_type)
          assert !blob_column.has_default?

          text_type = SqlTypeMetadata.new(type: :text)
          text_column = MySQL::Column.new("title", nil, text_type)
          assert !text_column.has_default?
        end
      end
    end
  end
end
