# frozen_string_literal: true

require "cases/migration/helper"

module ActiveRecord
  class Migration
    class ReferencesStatementsTest < ActiveRecord::TestCase
      include ActiveRecord::Migration::TestHelper

      def setup
        super
        @table_name = :test_models

        add_column table_name, :supplier_id, :integer
        add_index table_name, :supplier_id
      end

      def test_creates_reference_id_column
        add_reference table_name, :user
        assert column_exists?(table_name, :user_id, :integer)
      end

      def test_primary_key_and_references_columns_should_be_identical_type
        add_reference table_name, :user
        pk = connection.send(:column_for, :users, :id)
        ref = connection.send(:column_for, table_name, :user_id)
        assert_equal pk.sql_type, ref.sql_type
      end

      def test_does_not_create_reference_type_column
        add_reference table_name, :taggable
        assert_not column_exists?(table_name, :taggable_type, :string)
      end

      def test_creates_reference_type_column
        add_reference table_name, :taggable, polymorphic: true
        assert column_exists?(table_name, :taggable_type, :string)
      end

      def test_does_not_create_reference_id_index_if_index_is_false
        add_reference table_name, :user, index: false
        assert_not index_exists?(table_name, :user_id)
      end

      def test_create_reference_id_index_even_if_index_option_is_not_passed
        add_reference table_name, :user
        assert index_exists?(table_name, :user_id)
      end

      def test_creates_polymorphic_index
        add_reference table_name, :taggable, polymorphic: true, index: true
        assert index_exists?(table_name, [:taggable_type, :taggable_id])
      end

      def test_creates_reference_type_column_with_default
        add_reference table_name, :taggable, polymorphic: { default: "Photo" }, index: true
        assert column_exists?(table_name, :taggable_type, :string, default: "Photo")
      end

      def test_creates_reference_type_column_with_not_null
        connection.create_table table_name, force: true do |t|
          t.references :taggable, null: false, polymorphic: true
        end
        assert column_exists?(table_name, :taggable_id, :integer, null: false)
        assert column_exists?(table_name, :taggable_type, :string, null: false)
      end

      def test_does_not_share_options_with_reference_type_column
        add_reference table_name, :taggable, type: :integer, limit: 2, polymorphic: true
        assert column_exists?(table_name, :taggable_id, :integer, limit: 2)
        assert column_exists?(table_name, :taggable_type, :string)
        assert_not column_exists?(table_name, :taggable_type, :string, limit: 2)
      end

      def test_creates_named_index
        add_reference table_name, :tag, index: { name: "index_taggings_on_tag_id" }
        assert index_exists?(table_name, :tag_id, name: "index_taggings_on_tag_id")
      end

      def test_creates_named_unique_index
        add_reference table_name, :tag, index: { name: "index_taggings_on_tag_id", unique: true }
        assert index_exists?(table_name, :tag_id, name: "index_taggings_on_tag_id", unique: true)
      end

      def test_creates_reference_id_with_specified_type
        add_reference table_name, :user, type: :string
        assert column_exists?(table_name, :user_id, :string)
      end

      def test_deletes_reference_id_column
        remove_reference table_name, :supplier
        assert_not column_exists?(table_name, :supplier_id, :integer)
      end

      def test_deletes_reference_id_index
        remove_reference table_name, :supplier
        assert_not index_exists?(table_name, :supplier_id)
      end

      def test_does_not_delete_reference_type_column
        with_polymorphic_column do
          remove_reference table_name, :supplier

          assert_not column_exists?(table_name, :supplier_id, :integer)
          assert column_exists?(table_name, :supplier_type, :string)
        end
      end

      def test_deletes_reference_type_column
        with_polymorphic_column do
          remove_reference table_name, :supplier, polymorphic: true
          assert_not column_exists?(table_name, :supplier_type, :string)
        end
      end

      def test_deletes_polymorphic_index
        with_polymorphic_column do
          remove_reference table_name, :supplier, polymorphic: true
          assert_not index_exists?(table_name, [:supplier_id, :supplier_type])
        end
      end

      def test_add_belongs_to_alias
        add_belongs_to table_name, :user
        assert column_exists?(table_name, :user_id, :integer)
      end

      def test_remove_belongs_to_alias
        remove_belongs_to table_name, :supplier
        assert_not column_exists?(table_name, :supplier_id, :integer)
      end

      def test_responds_to_if_exists_option
        with_polymorphic_column do
          assert_nothing_raised do
            remove_reference table_name, :nonexistent, polymorphic: true, if_exists: true
          end
        end
      end

      def test_responds_to_if_not_exists_option
        with_polymorphic_column do
          assert_nothing_raised do
            add_reference table_name, :supplier, polymorphic: true, if_not_exists: true
          end
        end
      end

      private
        def with_polymorphic_column
          add_column table_name, :supplier_type, :string
          add_index table_name, [:supplier_id, :supplier_type]

          yield
        end
    end
  end
end
