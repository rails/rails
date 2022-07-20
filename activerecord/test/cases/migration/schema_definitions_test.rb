# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class SchemaDefinitionsTest < ActiveRecord::TestCase
      attr_reader :connection

      def setup
        @connection = ActiveRecord::Base.connection
      end

      def test_build_create_table_definition_with_block
        td = connection.build_create_table_definition :test do |t|
          t.column :foo, :string
        end

        id_column = td.columns.find { |col| col.name == "id" }
        assert_predicate id_column, :present?
        assert id_column.type
        assert id_column.sql_type

        foo_column = td.columns.find { |col| col.name == "foo" }
        assert_predicate foo_column, :present?
        assert foo_column.type
        assert foo_column.sql_type
      end

      def test_build_create_table_definition_without_block
        td = connection.build_create_table_definition(:test)

        id_column = td.columns.find { |col| col.name == "id" }
        assert_predicate id_column, :present?
        assert id_column.type
        assert id_column.sql_type
      end
    end
  end
end
