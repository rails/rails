require "cases/helper"

class ColumnDefinitionTest < ActiveRecord::TestCase
  def setup
    @adapter = ActiveRecord::ConnectionAdapters::AbstractAdapter.new(nil)
    def @adapter.native_database_types
      {:string => "varchar"}
    end
  end

  # Avoid column definitions in create table statements like:
  # `title` varchar(255) DEFAULT NULL
  def test_should_not_include_default_clause_when_default_is_null
    column = ActiveRecord::ConnectionAdapters::Column.new("title", nil, "varchar(20)")
    column_def = ActiveRecord::ConnectionAdapters::ColumnDefinition.new(
      @adapter, column.name, "string",
      column.limit, column.precision, column.scale, column.default, column.null)
    assert_equal "title varchar(20)", column_def.to_sql
  end

  def test_should_include_default_clause_when_default_is_present
    column = ActiveRecord::ConnectionAdapters::Column.new("title", "Hello", "varchar(20)")
    column_def = ActiveRecord::ConnectionAdapters::ColumnDefinition.new(
      @adapter, column.name, "string",
      column.limit, column.precision, column.scale, column.default, column.null)
    assert_equal %Q{title varchar(20) DEFAULT 'Hello'}, column_def.to_sql
  end

  def test_should_specify_not_null_if_null_option_is_false
    column = ActiveRecord::ConnectionAdapters::Column.new("title", "Hello", "varchar(20)", false)
    column_def = ActiveRecord::ConnectionAdapters::ColumnDefinition.new(
      @adapter, column.name, "string",
      column.limit, column.precision, column.scale, column.default, column.null)
    assert_equal %Q{title varchar(20) DEFAULT 'Hello' NOT NULL}, column_def.to_sql
  end

  if current_adapter?(:MysqlAdapter)
    def test_should_set_default_for_mysql_binary_data_types
      binary_column = ActiveRecord::ConnectionAdapters::MysqlColumn.new("title", "a", "binary(1)")
      assert_equal "a", binary_column.default

      varbinary_column = ActiveRecord::ConnectionAdapters::MysqlColumn.new("title", "a", "varbinary(1)")
      assert_equal "a", varbinary_column.default
    end

    def test_should_not_set_default_for_blob_and_text_data_types
      assert_raise ArgumentError do
        ActiveRecord::ConnectionAdapters::MysqlColumn.new("title", "a", "blob")
      end

      assert_raise ArgumentError do
        ActiveRecord::ConnectionAdapters::MysqlColumn.new("title", "Hello", "text")
      end

      text_column = ActiveRecord::ConnectionAdapters::MysqlColumn.new("title", nil, "text")
      assert_equal nil, text_column.default

      not_null_text_column = ActiveRecord::ConnectionAdapters::MysqlColumn.new("title", nil, "text", false)
      assert_equal "", not_null_text_column.default
    end

    def test_has_default_should_return_false_for_blog_and_test_data_types
      blob_column = ActiveRecord::ConnectionAdapters::MysqlColumn.new("title", nil, "blob")
      assert !blob_column.has_default?

      text_column = ActiveRecord::ConnectionAdapters::MysqlColumn.new("title", nil, "text")
      assert !text_column.has_default?
    end
  end
end
