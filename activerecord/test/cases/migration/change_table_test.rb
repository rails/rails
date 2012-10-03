require "cases/migration/helper"

module ActiveRecord
  class Migration
    class TableTest < ActiveRecord::TestCase
      class MockConnection < MiniTest::Mock
        def native_database_types
          {
            :string  => 'varchar(255)',
            :integer => 'integer',
          }
        end

        def type_to_sql(type, limit, precision, scale)
          native_database_types[type]
        end
      end

      def setup
        @connection = MockConnection.new
      end

      def teardown
        assert @connection.verify
      end

      def with_change_table
        yield ConnectionAdapters::Table.new(:delete_me, @connection)
      end

      def test_references_column_type_adds_id
        with_change_table do |t|
          @connection.expect :add_reference, nil, [:delete_me, :customer, {}]
          t.references :customer
        end
      end

      def test_remove_references_column_type_removes_id
        with_change_table do |t|
          @connection.expect :remove_reference, nil, [:delete_me, :customer, {}]
          t.remove_references :customer
        end
      end

      def test_add_belongs_to_works_like_add_references
        with_change_table do |t|
          @connection.expect :add_reference, nil, [:delete_me, :customer, {}]
          t.belongs_to :customer
        end
      end

      def test_remove_belongs_to_works_like_remove_references
        with_change_table do |t|
          @connection.expect :remove_reference, nil, [:delete_me, :customer, {}]
          t.remove_belongs_to :customer
        end
      end

      def test_references_column_type_with_polymorphic_adds_type
        with_change_table do |t|
          @connection.expect :add_reference, nil, [:delete_me, :taggable, polymorphic: true]
          t.references :taggable, polymorphic: true
        end
      end

      def test_remove_references_column_type_with_polymorphic_removes_type
        with_change_table do |t|
          @connection.expect :remove_reference, nil, [:delete_me, :taggable, polymorphic: true]
          t.remove_references :taggable, polymorphic: true
        end
      end

      def test_references_column_type_with_polymorphic_and_options_null_is_false_adds_table_flag
        with_change_table do |t|
          @connection.expect :add_reference, nil, [:delete_me, :taggable, polymorphic: true, null: false]
          t.references :taggable, polymorphic: true, null: false
        end
      end

      def test_remove_references_column_type_with_polymorphic_and_options_null_is_false_removes_table_flag
        with_change_table do |t|
          @connection.expect :remove_reference, nil, [:delete_me, :taggable, polymorphic: true, null: false]
          t.remove_references :taggable, polymorphic: true, null: false
        end
      end

      def test_timestamps_creates_updated_at_and_created_at
        with_change_table do |t|
          @connection.expect :add_timestamps, nil, [:delete_me]
          t.timestamps
        end
      end

      def test_remove_timestamps_creates_updated_at_and_created_at
        with_change_table do |t|
          @connection.expect :remove_timestamps, nil, [:delete_me]
          t.remove_timestamps
        end
      end

      def string_column
        @connection.native_database_types[:string]
      end

      def integer_column
        @connection.native_database_types[:integer]
      end

      def test_integer_creates_integer_column
        with_change_table do |t|
          @connection.expect :add_column, nil, [:delete_me, :foo, integer_column, {}]
          @connection.expect :add_column, nil, [:delete_me, :bar, integer_column, {}]
          t.integer :foo, :bar
        end
      end

      def test_string_creates_string_column
        with_change_table do |t|
          @connection.expect :add_column, nil, [:delete_me, :foo, string_column, {}]
          @connection.expect :add_column, nil, [:delete_me, :bar, string_column, {}]
          t.string :foo, :bar
        end
      end

      def test_column_creates_column
        with_change_table do |t|
          @connection.expect :add_column, nil, [:delete_me, :bar, :integer, {}]
          t.column :bar, :integer
        end
      end

      def test_column_creates_column_with_options
        with_change_table do |t|
          @connection.expect :add_column, nil, [:delete_me, :bar, :integer, {:null => false}]
          t.column :bar, :integer, :null => false
        end
      end

      def test_index_creates_index
        with_change_table do |t|
          @connection.expect :add_index, nil, [:delete_me, :bar, {}]
          t.index :bar
        end
      end

      def test_index_creates_index_with_options
        with_change_table do |t|
          @connection.expect :add_index, nil, [:delete_me, :bar, {:unique => true}]
          t.index :bar, :unique => true
        end
      end

      def test_index_exists
        with_change_table do |t|
          @connection.expect :index_exists?, nil, [:delete_me, :bar, {}]
          t.index_exists?(:bar)
        end
      end

      def test_index_exists_with_options
        with_change_table do |t|
          @connection.expect :index_exists?, nil, [:delete_me, :bar, {:unique => true}]
          t.index_exists?(:bar, :unique => true)
        end
      end

      def test_change_changes_column
        with_change_table do |t|
          @connection.expect :change_column, nil, [:delete_me, :bar, :string, {}]
          t.change :bar, :string
        end
      end

      def test_change_changes_column_with_options
        with_change_table do |t|
          @connection.expect :change_column, nil, [:delete_me, :bar, :string, {:null => true}]
          t.change :bar, :string, :null => true
        end
      end

      def test_change_default_changes_column
        with_change_table do |t|
          @connection.expect :change_column_default, nil, [:delete_me, :bar, :string]
          t.change_default :bar, :string
        end
      end

      def test_remove_drops_single_column
        with_change_table do |t|
          @connection.expect :remove_column, nil, [:delete_me, :bar]
          t.remove :bar
        end
      end

      def test_remove_drops_multiple_columns
        with_change_table do |t|
          @connection.expect :remove_column, nil, [:delete_me, :bar, :baz]
          t.remove :bar, :baz
        end
      end

      def test_remove_index_removes_index_with_options
        with_change_table do |t|
          @connection.expect :remove_index, nil, [:delete_me, {:unique => true}]
          t.remove_index :unique => true
        end
      end

      def test_rename_renames_column
        with_change_table do |t|
          @connection.expect :rename_column, nil, [:delete_me, :bar, :baz]
          t.rename :bar, :baz
        end
      end
    end
  end
end
