# frozen_string_literal: true

require "cases/migration/helper"

module ActiveRecord
  class Migration
    class InvalidOptionsTest < ActiveRecord::TestCase
      include ActiveRecord::Migration::TestHelper

      def invalid_add_column_option_exception_message(key)
        default_keys = [":limit", ":precision", ":scale", ":default", ":null", ":collation", ":comment", ":primary_key", ":if_exists", ":if_not_exists"]

        if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
          default_keys.concat([":auto_increment", ":charset", ":as", ":size", ":unsigned", ":first", ":after", ":type", ":stored"])
        elsif current_adapter?(:PostgreSQLAdapter)
          default_keys.concat([":array", ":using", ":cast_as", ":as", ":type", ":enum_type", ":stored"])
        elsif current_adapter?(:SQLite3Adapter)
          default_keys.concat([":as", ":type", ":stored"])
        end

        "Unknown key: :#{key}. Valid keys are: #{default_keys.join(", ")}"
      end

      def invalid_add_index_option_exception_message(key)
        "Unknown key: :#{key}. Valid keys are: :unique, :length, :order, :opclass, :where, :type, :using, :comment, :algorithm, :include, :nulls_not_distinct"
      end

      def invalid_create_table_option_exception_message(key)
        table_keys = [":temporary", ":if_not_exists", ":options", ":as", ":comment", ":charset", ":collation"]
        primary_keys = [":limit", ":default", ":precision"]

        if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
          primary_keys.concat([":unsigned", ":auto_increment"])
        elsif current_adapter?(:SQLite3Adapter)
          table_keys.concat([":rename"])
        end

        "Unknown key: :#{key}. Valid keys are: #{(table_keys + primary_keys).join(", ")}"
      end

      def test_add_reference_with_invalid_options
        exception = assert_raises(ArgumentError) do
          connection.create_table "my_table", force: true do |t|
            t.references :some_table, boring_key: true
          end
        end

        assert_equal(
          invalid_add_column_option_exception_message(:boring_key),
          exception.message
        )

        exception = assert_raises(ArgumentError) do
          add_reference :some_table, :some_column, boring_key: true
        end

        assert_equal(
          invalid_add_column_option_exception_message(:boring_key),
          exception.message
        )
      ensure
        connection.drop_table :my_table, if_exists: true
      end

      def test_add_column_with_invalid_options
        exception = assert_raises(ArgumentError) do
          add_column "test_models", "first_name", :string, preccision: true
        end

        assert_equal(
          invalid_add_column_option_exception_message(:preccision),
          exception.message
        )

        exception = assert_raises(ArgumentError) do
          connection.create_table "my_table", force: true do |t|
            t.string :first_name, index: { nema: "test" }
          end
        end

        assert_equal(
          invalid_add_index_option_exception_message(:nema),
          exception.message
        )
      ensure
        connection.drop_table :my_table, if_exists: true
      end

      def test_add_index_with_invalid_options
        exception = assert_raises(ArgumentError) do
          add_index "test_models", "first_name", nema: "my_index"
        end

        assert_equal(
          invalid_add_index_option_exception_message(:nema),
          exception.message
        )
      end

      if current_adapter?(:Mysql2Adapter, :TrilogyAdapter, :PostgreSQLAdapter)
        def test_change_column_with_invalid_options
          exception = assert_raises(ArgumentError) do
            change_column "posts", "title", :text, liimit: true
          end

          assert_equal(
            invalid_add_column_option_exception_message(:liimit),
            exception.message
          )
        end
      end

      def test_create_table_with_invalid_options
        exception = assert_raises(ArgumentError) do
          connection.create_table "my_table", idd: false do |t|
          end
        end

        assert_equal(
          invalid_create_table_option_exception_message(:idd),
          exception.message
        )
      end
    end
  end
end
