# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class SchemaDefinitionsTest < ActiveRecord::TestCase
      attr_reader :connection

      def setup
        @connection = ActiveRecord::Base.lease_connection
      end

      def test_build_create_table_definition_with_block
        td = connection.build_create_table_definition :test do |t|
          t.column :foo, :string
        end

        id_column = td.columns.find { |col| col.name == "id" }
        assert_predicate id_column, :present?

        foo_column = td.columns.find { |col| col.name == "foo" }
        assert_predicate foo_column, :present?
      end

      def test_build_create_table_definition_without_block
        td = connection.build_create_table_definition(:test)

        id_column = td.columns.find { |col| col.name == "id" }
        assert_predicate id_column, :present?
      end

      def test_build_create_join_table_definition_with_block
        assert connection.table_exists?(:posts)
        assert connection.table_exists?(:comments)

        join_td = connection.build_create_join_table_definition(:posts, :comments) do |t|
          t.column :another_col, :string
        end

        assert_equal :comments_posts, join_td.name
        assert_equal ["another_col", "comment_id", "post_id"], join_td.columns.map(&:name).sort
      end

      def test_build_create_join_table_definition_without_block
        assert connection.table_exists?(:posts)
        assert connection.table_exists?(:comments)

        join_td = connection.build_create_join_table_definition(:posts, :comments)

        assert_equal :comments_posts, join_td.name
        assert_equal ["comment_id", "post_id"], join_td.columns.map(&:name).sort
      end

      def test_build_create_index_definition
        connection.create_table(:test) do |t|
          t.column :foo, :string
        end
        create_index = connection.build_create_index_definition(:test, :foo)

        assert_equal "index_test_on_foo", create_index.index.name
      ensure
        connection.drop_table(:test) if connection.table_exists?(:test)
      end

      if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        def test_build_create_index_definition_for_existing_index
          connection.create_table(:test) do |t|
            t.column :foo, :string
          end
          connection.add_index(:test, :foo)

          create_index = connection.build_create_index_definition(:test, :foo, if_not_exists: true)
          assert_nil create_index
        ensure
          connection.drop_table(:test) if connection.table_exists?(:test)
        end
      end

      unless current_adapter?(:SQLite3Adapter)
        def test_build_change_column_definition
          connection.create_table(:test) do |t|
            t.column :foo, :string
          end

          change_cd = connection.build_change_column_definition(:test, :foo, :integer)
          change_col = change_cd.column
          assert_equal "foo", change_col.name.to_s
        ensure
          connection.drop_table(:test) if connection.table_exists?(:test)
        end

        def test_build_change_column_default_definition
          connection.create_table(:test) do |t|
            t.column :foo, :string
          end

          change_default_cd = connection.build_change_column_default_definition(:test, :foo, "new")
          assert_equal "new", change_default_cd.default

          change_col = change_default_cd.column
          assert_equal "foo", change_col.name.to_s
        ensure
          connection.drop_table(:test) if connection.table_exists?(:test)
        end
      end
    end
  end
end
