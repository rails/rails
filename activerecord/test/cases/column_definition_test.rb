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
        column_def = ColumnDefinition.new("title", "string", limit: 20)
        assert_equal "title varchar(20)", @viz.accept(column_def)
      end

      def test_should_include_default_clause_when_default_is_present
        column_def = ColumnDefinition.new("title", "string", limit: 20, default: "Hello")
        assert_equal "title varchar(20) DEFAULT 'Hello'", @viz.accept(column_def)
      end

      def test_should_specify_not_null_if_null_option_is_false
        column_def = ColumnDefinition.new("title", "string", limit: 20, default: "Hello", null: false)
        assert_equal "title varchar(20) DEFAULT 'Hello' NOT NULL", @viz.accept(column_def)
      end
    end
  end
end
