require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ColumnDefinitionTest < ActiveRecord::TestCase
      def setup
        @adapter = AbstractAdapter.new(nil)
        def @adapter.native_database_types
          {:string => "varchar"}
        end
        @viz = @adapter.schema_creation
      end

      # Avoid column definitions in create table statements like:
      # `title` varchar(255) DEFAULT NULL
      def test_should_not_include_default_clause_when_default_is_null
        column = Column.new("title", nil, Type::String.new(limit: 20))
        column_def = ColumnDefinition.new(
          column.name, "string",
          column.limit, column.precision, column.scale, column.default, column.null)
          assert_equal "title varchar(20)", @viz.accept(column_def)
      end

      def test_should_include_default_clause_when_default_is_present
        column = Column.new("title", "Hello", Type::String.new(limit: 20))
        column_def = ColumnDefinition.new(
          column.name, "string",
          column.limit, column.precision, column.scale, column.default, column.null)
          assert_equal %Q{title varchar(20) DEFAULT 'Hello'}, @viz.accept(column_def)
      end

      def test_should_specify_not_null_if_null_option_is_false
        column = Column.new("title", "Hello", Type::String.new(limit: 20), "varchar(20)", false)
        column_def = ColumnDefinition.new(
          column.name, "string",
          column.limit, column.precision, column.scale, column.default, column.null)
          assert_equal %Q{title varchar(20) DEFAULT 'Hello' NOT NULL}, @viz.accept(column_def)
      end

      if current_adapter?(:MysqlAdapter)
        def test_should_set_default_for_mysql_binary_data_types
          binary_column = MysqlAdapter::Column.new("title", "a", Type::Binary.new, "binary(1)")
          assert_equal "a", binary_column.default

          varbinary_column = MysqlAdapter::Column.new("title", "a", Type::Binary.new, "varbinary(1)")
          assert_equal "a", varbinary_column.default
        end

        def test_should_not_set_default_for_blob_and_text_data_types
          assert_raise ArgumentError do
            MysqlAdapter::Column.new("title", "a", Type::Binary.new, "blob")
          end

          assert_raise ArgumentError do
            MysqlAdapter::Column.new("title", "Hello", Type::Text.new)
          end

          text_column = MysqlAdapter::Column.new("title", nil, Type::Text.new)
          assert_equal nil, text_column.default

          not_null_text_column = MysqlAdapter::Column.new("title", nil, Type::Text.new, "text", false)
          assert_equal "", not_null_text_column.default
        end

        def test_has_default_should_return_false_for_blob_and_text_data_types
          blob_column = MysqlAdapter::Column.new("title", nil, Type::Binary.new, "blob")
          assert !blob_column.has_default?

          text_column = MysqlAdapter::Column.new("title", nil, Type::Text.new)
          assert !text_column.has_default?
        end
      end

      if current_adapter?(:Mysql2Adapter)
        def test_should_set_default_for_mysql_binary_data_types
          binary_column = Mysql2Adapter::Column.new("title", "a", Type::Binary.new, "binary(1)")
          assert_equal "a", binary_column.default

          varbinary_column = Mysql2Adapter::Column.new("title", "a", Type::Binary.new, "varbinary(1)")
          assert_equal "a", varbinary_column.default
        end

        def test_should_not_set_default_for_blob_and_text_data_types
          assert_raise ArgumentError do
            Mysql2Adapter::Column.new("title", "a", Type::Binary.new, "blob")
          end

          assert_raise ArgumentError do
            Mysql2Adapter::Column.new("title", "Hello", Type::Text.new)
          end

          text_column = Mysql2Adapter::Column.new("title", nil, Type::Text.new)
          assert_equal nil, text_column.default

          not_null_text_column = Mysql2Adapter::Column.new("title", nil, Type::Text.new, "text", false)
          assert_equal "", not_null_text_column.default
        end

        def test_has_default_should_return_false_for_blob_and_text_data_types
          blob_column = Mysql2Adapter::Column.new("title", nil, Type::Binary.new, "blob")
          assert !blob_column.has_default?

          text_column = Mysql2Adapter::Column.new("title", nil, Type::Text.new)
          assert !text_column.has_default?
        end
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_bigint_column_should_map_to_integer
          oid = PostgreSQLAdapter::OID::Integer.new
          bigint_column = PostgreSQLColumn.new('number', nil, oid, "bigint")
          assert_equal :integer, bigint_column.type
        end

        def test_smallint_column_should_map_to_integer
          oid = PostgreSQLAdapter::OID::Integer.new
          smallint_column = PostgreSQLColumn.new('number', nil, oid, "smallint")
          assert_equal :integer, smallint_column.type
        end
      end
    end
  end
end
