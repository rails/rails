# frozen_string_literal: true

require "cases/migration/helper"

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
        yield ActiveRecord::Base.lease_connection.update_table_definition(:delete_me, @connection)
      end

      if Minitest::Mock.instance_method(:expect).parameters.map(&:first).include?(:keyrest)
        def expect(method, returns, args, **kwargs)
          @connection.expect(method, returns, args, **kwargs)
        end
      else
        def expect(method, returns, args, **kwargs)
          if !kwargs.empty?
            @connection.expect(method, returns, [*args, kwargs])
          else
            @connection.expect(method, returns, args)
          end
        end
      end

      def test_references_column_type_adds_id
        with_change_table do |t|
          expect :add_reference, nil, [:delete_me, :customer]
          t.references :customer
        end
      end

      def test_remove_references_column_type_removes_id
        with_change_table do |t|
          expect :remove_reference, nil, [:delete_me, :customer]
          t.remove_references :customer
        end
      end

      def test_add_belongs_to_works_like_add_references
        with_change_table do |t|
          expect :add_reference, nil, [:delete_me, :customer]
          t.belongs_to :customer
        end
      end

      def test_remove_belongs_to_works_like_remove_references
        with_change_table do |t|
          expect :remove_reference, nil, [:delete_me, :customer]
          t.remove_belongs_to :customer
        end
      end

      def test_references_column_type_with_polymorphic_adds_type
        with_change_table do |t|
          expect :add_reference, nil, [:delete_me, :taggable], polymorphic: true
          t.references :taggable, polymorphic: true
        end
      end

      def test_remove_references_column_type_with_polymorphic_removes_type
        with_change_table do |t|
          expect :remove_reference, nil, [:delete_me, :taggable], polymorphic: true
          t.remove_references :taggable, polymorphic: true
        end
      end

      def test_references_column_type_with_polymorphic_and_options_null_is_false_adds_table_flag
        with_change_table do |t|
          expect :add_reference, nil, [:delete_me, :taggable], polymorphic: true, null: false
          t.references :taggable, polymorphic: true, null: false
        end
      end

      def test_remove_references_column_type_with_polymorphic_and_options_null_is_false_removes_table_flag
        with_change_table do |t|
          expect :remove_reference, nil, [:delete_me, :taggable], polymorphic: true, null: false
          t.remove_references :taggable, polymorphic: true, null: false
        end
      end

      def test_references_column_type_with_polymorphic_and_type
        with_change_table do |t|
          expect :add_reference, nil, [:delete_me, :taggable], polymorphic: true, type: :string
          t.references :taggable, polymorphic: true, type: :string
        end
      end

      def test_remove_references_column_type_with_polymorphic_and_type
        with_change_table do |t|
          expect :remove_reference, nil, [:delete_me, :taggable], polymorphic: true, type: :string
          t.remove_references :taggable, polymorphic: true, type: :string
        end
      end

      def test_timestamps_creates_updated_at_and_created_at
        with_change_table do |t|
          expect :add_timestamps, nil, [:delete_me], null: true
          t.timestamps null: true
        end
      end

      def test_remove_timestamps_creates_updated_at_and_created_at
        with_change_table do |t|
          expect :remove_timestamps, nil, [:delete_me], null: true
          t.remove_timestamps(null: true)
        end
      end

      def test_primary_key_creates_primary_key_column
        with_change_table do |t|
          expect :add_column, nil, [:delete_me, :id, :primary_key], primary_key: true, first: true
          t.primary_key :id, first: true
        end
      end

      def test_integer_creates_integer_column
        with_change_table do |t|
          expect :add_column, nil, [:delete_me, :foo, :integer]
          expect :add_column, nil, [:delete_me, :bar, :integer]
          t.integer :foo, :bar
        end
      end

      def test_bigint_creates_bigint_column
        with_change_table do |t|
          expect :add_column, nil, [:delete_me, :foo, :bigint]
          expect :add_column, nil, [:delete_me, :bar, :bigint]
          t.bigint :foo, :bar
        end
      end

      def test_string_creates_string_column
        with_change_table do |t|
          expect :add_column, nil, [:delete_me, :foo, :string]
          expect :add_column, nil, [:delete_me, :bar, :string]
          t.string :foo, :bar
        end
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_json_creates_json_column
          with_change_table do |t|
            expect :add_column, nil, [:delete_me, :foo, :json]
            expect :add_column, nil, [:delete_me, :bar, :json]
            t.json :foo, :bar
          end
        end

        def test_xml_creates_xml_column
          with_change_table do |t|
            expect :add_column, nil, [:delete_me, :foo, :xml]
            expect :add_column, nil, [:delete_me, :bar, :xml]
            t.xml :foo, :bar
          end
        end

        def test_exclusion_constraint_creates_exclusion_constraint
          with_change_table do |t|
            expect :add_exclusion_constraint, nil, [:delete_me, "daterange(start_date, end_date) WITH &&"], using: :gist, where: "start_date IS NOT NULL AND end_date IS NOT NULL", name: "date_overlap"
            t.exclusion_constraint "daterange(start_date, end_date) WITH &&", using: :gist, where: "start_date IS NOT NULL AND end_date IS NOT NULL", name: "date_overlap"
          end
        end

        def test_remove_exclusion_constraint_removes_exclusion_constraint
          with_change_table do |t|
            expect :remove_exclusion_constraint, nil, [:delete_me], name: "date_overlap"
            t.remove_exclusion_constraint name: "date_overlap"
          end
        end

        def test_unique_constraint_creates_unique_constraint
          with_change_table do |t|
            expect :add_unique_constraint, nil, [:delete_me, :foo], deferrable: :deferred, name: "unique_constraint"
            t.unique_constraint :foo, deferrable: :deferred, name: "unique_constraint"
          end
        end

        def test_remove_unique_constraint_removes_unique_constraint
          with_change_table do |t|
            expect :remove_unique_constraint, nil, [:delete_me], name: "unique_constraint"
            t.remove_unique_constraint name: "unique_constraint"
          end
        end
      end

      def test_column_creates_column
        with_change_table do |t|
          expect :add_column, nil, [:delete_me, :bar, :integer]
          t.column :bar, :integer
        end
      end

      def test_column_creates_column_with_options
        with_change_table do |t|
          expect :add_column, nil, [:delete_me, :bar, :integer], null: false
          t.column :bar, :integer, null: false
        end
      end

      def test_column_creates_column_with_index
        with_change_table do |t|
          expect :add_column, nil, [:delete_me, :bar, :integer]
          expect :add_index, nil, [:delete_me, :bar]
          t.column :bar, :integer, index: true
        end
      end

      def test_index_creates_index
        with_change_table do |t|
          expect :add_index, nil, [:delete_me, :bar]
          t.index :bar
        end
      end

      def test_index_creates_index_with_options
        with_change_table do |t|
          expect :add_index, nil, [:delete_me, :bar], unique: true
          t.index :bar, unique: true
        end
      end

      def test_index_exists
        with_change_table do |t|
          expect :index_exists?, nil, [:delete_me, :bar]
          t.index_exists?(:bar)
        end
      end

      def test_index_exists_with_options
        with_change_table do |t|
          expect :index_exists?, nil, [:delete_me, :bar], unique: true
          t.index_exists?(:bar, unique: true)
        end
      end

      def test_rename_index_renames_index
        with_change_table do |t|
          expect :rename_index, nil, [:delete_me, :bar, :baz]
          t.rename_index :bar, :baz
        end
      end

      def test_change_changes_column
        with_change_table do |t|
          expect :change_column, nil, [:delete_me, :bar, :string]
          t.change :bar, :string
        end
      end

      def test_change_changes_column_with_options
        with_change_table do |t|
          expect :change_column, nil, [:delete_me, :bar, :string], null: true
          t.change :bar, :string, null: true
        end
      end

      def test_change_default_changes_column
        with_change_table do |t|
          expect :change_column_default, nil, [:delete_me, :bar, :string]
          t.change_default :bar, :string
        end
      end

      def test_change_null_changes_column
        with_change_table do |t|
          expect :change_column_null, nil, [:delete_me, :bar, true, nil]
          t.change_null :bar, true
        end
      end

      def test_remove_drops_single_column
        with_change_table do |t|
          expect :remove_columns, nil, [:delete_me, :bar]
          t.remove :bar
        end
      end

      def test_remove_drops_multiple_columns
        with_change_table do |t|
          expect :remove_columns, nil, [:delete_me, :bar, :baz]
          t.remove :bar, :baz
        end
      end

      def test_remove_drops_multiple_columns_when_column_options_are_given
        with_change_table do |t|
          expect :remove_columns, nil, [:delete_me, :bar, :baz], type: :string, null: false
          t.remove :bar, :baz, type: :string, null: false
        end
      end

      def test_remove_index_removes_index_with_options
        with_change_table do |t|
          expect :remove_index, nil, [:delete_me, :bar], unique: true
          t.remove_index :bar, unique: true
        end
      end

      def test_rename_renames_column
        with_change_table do |t|
          expect :rename_column, nil, [:delete_me, :bar, :baz]
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
          expect :add_check_constraint, nil, [:delete_me, "price > discounted_price"], name: "price_check"
          t.check_constraint "price > discounted_price", name: "price_check"
        end
      end

      def test_check_constraint_exists
        with_change_table do |t|
          expect :check_constraint_exists?, nil, [:delete_me], name: "price_check"
          assert_not t.check_constraint_exists?(name: "price_check")
        end
      end

      def test_remove_check_constraint_removes_check_constraint
        with_change_table do |t|
          expect :remove_check_constraint, nil, [:delete_me], name: "price_check"
          t.remove_check_constraint name: "price_check"
        end
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_validate_check_constraint
          with_change_table do |t|
            expect :add_check_constraint, nil, [:delete_me, "price > discounted_price"], name: "price_check", validate: false
            t.check_constraint "price > discounted_price", name: "price_check", validate: false
            expect :validate_check_constraint, :nil, [:delete_me, "price_check"]
            t.validate_check_constraint "price_check"
          end
        end

        def test_validate_constraint
          with_change_table do |t|
            expect :add_check_constraint, nil, [:delete_me, "price > discounted_price"], name: "price_check", validate: false
            t.check_constraint "price > discounted_price", name: "price_check", validate: false
            expect :validate_constraint, :nil, [:delete_me, "price_check"]
            t.validate_constraint "price_check"
          end
        end
      end

      def test_remove_column_with_if_exists_raises_error
        assert_raises(ArgumentError) do
          with_change_table do |t|
            t.remove :name, if_exists: true
          end
        end
      end

      def test_add_column_with_if_not_exists_raises_error
        assert_raises(ArgumentError) do
          with_change_table do |t|
            t.string :nickname, if_not_exists: true
          end
        end
      end
    end
  end
end
