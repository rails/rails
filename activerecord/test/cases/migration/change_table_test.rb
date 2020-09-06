# frozen_string_literal: true

require 'cases/migration/helper'

module ActiveRecord
  class Migration
    class TableTest < ActiveRecord::TestCase
      def setup
        @connection = Minitest::Mock.new
      end

      teardown do
        assert @connection.verify
      end

      def with_change_table
        yield ActiveRecord::Base.connection.update_table_definition(:delete_me, @connection)
      end

      def test_references_column_type_adds_id
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :add_reference, nil, [:delete_me, :customer, {}]
          else
            @connection.expect :add_reference, nil, [:delete_me, :customer]
          end
          t.references :customer
        end
      end

      def test_remove_references_column_type_removes_id
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :remove_reference, nil, [:delete_me, :customer, {}]
          else
            @connection.expect :remove_reference, nil, [:delete_me, :customer]
          end
          t.remove_references :customer
        end
      end

      def test_add_belongs_to_works_like_add_references
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :add_reference, nil, [:delete_me, :customer, {}]
          else
            @connection.expect :add_reference, nil, [:delete_me, :customer]
          end
          t.belongs_to :customer
        end
      end

      def test_remove_belongs_to_works_like_remove_references
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :remove_reference, nil, [:delete_me, :customer, {}]
          else
            @connection.expect :remove_reference, nil, [:delete_me, :customer]
          end
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

      def test_references_column_type_with_polymorphic_and_type
        with_change_table do |t|
          @connection.expect :add_reference, nil, [:delete_me, :taggable, polymorphic: true, type: :string]
          t.references :taggable, polymorphic: true, type: :string
        end
      end

      def test_remove_references_column_type_with_polymorphic_and_type
        with_change_table do |t|
          @connection.expect :remove_reference, nil, [:delete_me, :taggable, polymorphic: true, type: :string]
          t.remove_references :taggable, polymorphic: true, type: :string
        end
      end

      def test_timestamps_creates_updated_at_and_created_at
        with_change_table do |t|
          @connection.expect :add_timestamps, nil, [:delete_me, null: true]
          t.timestamps null: true
        end
      end

      def test_remove_timestamps_creates_updated_at_and_created_at
        with_change_table do |t|
          @connection.expect :remove_timestamps, nil, [:delete_me, { null: true }]
          t.remove_timestamps(null: true)
        end
      end

      def test_primary_key_creates_primary_key_column
        with_change_table do |t|
          @connection.expect :add_column, nil, [:delete_me, :id, :primary_key, primary_key: true, first: true]
          t.primary_key :id, first: true
        end
      end

      def test_integer_creates_integer_column
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :add_column, nil, [:delete_me, :foo, :integer, {}]
            @connection.expect :add_column, nil, [:delete_me, :bar, :integer, {}]
          else
            @connection.expect :add_column, nil, [:delete_me, :foo, :integer]
            @connection.expect :add_column, nil, [:delete_me, :bar, :integer]
          end
          t.integer :foo, :bar
        end
      end

      def test_bigint_creates_bigint_column
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :add_column, nil, [:delete_me, :foo, :bigint, {}]
            @connection.expect :add_column, nil, [:delete_me, :bar, :bigint, {}]
          else
            @connection.expect :add_column, nil, [:delete_me, :foo, :bigint]
            @connection.expect :add_column, nil, [:delete_me, :bar, :bigint]
          end
          t.bigint :foo, :bar
        end
      end

      def test_string_creates_string_column
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :add_column, nil, [:delete_me, :foo, :string, {}]
            @connection.expect :add_column, nil, [:delete_me, :bar, :string, {}]
          else
            @connection.expect :add_column, nil, [:delete_me, :foo, :string]
            @connection.expect :add_column, nil, [:delete_me, :bar, :string]
          end
          t.string :foo, :bar
        end
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_json_creates_json_column
          with_change_table do |t|
            if RUBY_VERSION < '2.7'
              @connection.expect :add_column, nil, [:delete_me, :foo, :json, {}]
              @connection.expect :add_column, nil, [:delete_me, :bar, :json, {}]
            else
              @connection.expect :add_column, nil, [:delete_me, :foo, :json]
              @connection.expect :add_column, nil, [:delete_me, :bar, :json]
            end
            t.json :foo, :bar
          end
        end

        def test_xml_creates_xml_column
          with_change_table do |t|
            if RUBY_VERSION < '2.7'
              @connection.expect :add_column, nil, [:delete_me, :foo, :xml, {}]
              @connection.expect :add_column, nil, [:delete_me, :bar, :xml, {}]
            else
              @connection.expect :add_column, nil, [:delete_me, :foo, :xml]
              @connection.expect :add_column, nil, [:delete_me, :bar, :xml]
            end
            t.xml :foo, :bar
          end
        end
      end

      def test_column_creates_column
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :add_column, nil, [:delete_me, :bar, :integer, {}]
          else
            @connection.expect :add_column, nil, [:delete_me, :bar, :integer]
          end
          t.column :bar, :integer
        end
      end

      def test_column_creates_column_with_options
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :add_column, nil, [:delete_me, :bar, :integer, { null: false }]
          else
            @connection.expect :add_column, nil, [:delete_me, :bar, :integer, { null: false }]
          end
          t.column :bar, :integer, null: false
        end
      end

      def test_column_creates_column_with_index
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :add_column, nil, [:delete_me, :bar, :integer, {}]
            @connection.expect :add_index, nil, [:delete_me, :bar, {}]
          else
            @connection.expect :add_column, nil, [:delete_me, :bar, :integer]
            @connection.expect :add_index, nil, [:delete_me, :bar]
          end
          t.column :bar, :integer, index: true
        end
      end

      def test_index_creates_index
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :add_index, nil, [:delete_me, :bar, {}]
          else
            @connection.expect :add_index, nil, [:delete_me, :bar]
          end
          t.index :bar
        end
      end

      def test_index_creates_index_with_options
        with_change_table do |t|
          @connection.expect :add_index, nil, [:delete_me, :bar, { unique: true }]
          t.index :bar, unique: true
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
          @connection.expect :index_exists?, nil, [:delete_me, :bar, { unique: true }]
          t.index_exists?(:bar, unique: true)
        end
      end

      def test_rename_index_renames_index
        with_change_table do |t|
          @connection.expect :rename_index, nil, [:delete_me, :bar, :baz]
          t.rename_index :bar, :baz
        end
      end

      def test_change_changes_column
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :change_column, nil, [:delete_me, :bar, :string, {}]
          else
            @connection.expect :change_column, nil, [:delete_me, :bar, :string]
          end
          t.change :bar, :string
        end
      end

      def test_change_changes_column_with_options
        with_change_table do |t|
          @connection.expect :change_column, nil, [:delete_me, :bar, :string, { null: true }]
          t.change :bar, :string, null: true
        end
      end

      def test_change_default_changes_column
        with_change_table do |t|
          @connection.expect :change_column_default, nil, [:delete_me, :bar, :string]
          t.change_default :bar, :string
        end
      end

      def test_change_null_changes_column
        with_change_table do |t|
          @connection.expect :change_column_null, nil, [:delete_me, :bar, true, nil]
          t.change_null :bar, true
        end
      end

      def test_remove_drops_single_column
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :remove_columns, nil, [:delete_me, :bar, {}]
          else
            @connection.expect :remove_columns, nil, [:delete_me, :bar]
          end
          t.remove :bar
        end
      end

      def test_remove_drops_multiple_columns
        with_change_table do |t|
          if RUBY_VERSION < '2.7'
            @connection.expect :remove_columns, nil, [:delete_me, :bar, :baz, {}]
          else
            @connection.expect :remove_columns, nil, [:delete_me, :bar, :baz]
          end
          t.remove :bar, :baz
        end
      end

      def test_remove_drops_multiple_columns_when_column_options_are_given
        with_change_table do |t|
          @connection.expect :remove_columns, nil, [:delete_me, :bar, :baz, type: :string, null: false]
          t.remove :bar, :baz, type: :string, null: false
        end
      end

      def test_remove_index_removes_index_with_options
        with_change_table do |t|
          @connection.expect :remove_index, nil, [:delete_me, :bar, { unique: true }]
          t.remove_index :bar, unique: true
        end
      end

      def test_rename_renames_column
        with_change_table do |t|
          @connection.expect :rename_column, nil, [:delete_me, :bar, :baz]
          t.rename :bar, :baz
        end
      end

      def test_table_name_set
        with_change_table do |t|
          assert_equal :delete_me, t.name
        end
      end

      def test_check_constraint_creates_check_constraint
        with_change_table do |t|
          @connection.expect :add_check_constraint, nil, [:delete_me, 'price > discounted_price', name: 'price_check']
          t.check_constraint 'price > discounted_price', name: 'price_check'
        end
      end

      def test_remove_check_constraint_removes_check_constraint
        with_change_table do |t|
          @connection.expect :remove_check_constraint, nil, [:delete_me, name: 'price_check']
          t.remove_check_constraint name: 'price_check'
        end
      end
    end
  end
end
