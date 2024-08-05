# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class ReferencesIndexTest < ActiveRecord::TestCase
      attr_reader :connection, :table_name

      def setup
        super
        @connection = ActiveRecord::Base.lease_connection
        @table_name = :testings
      end

      teardown do
        connection.drop_table :testings rescue nil
      end

      def test_creates_index
        connection.create_table table_name do |t|
          t.references :foo, index: true
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_creates_index_by_default_even_if_index_option_is_not_passed
        connection.create_table table_name do |t|
          t.references :foo
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_does_not_create_index_explicit
        connection.create_table table_name do |t|
          t.references :foo, index: false
        end

        assert_not connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_creates_index_with_options
        connection.create_table table_name do |t|
          t.references :foo, index: { name: :index_testings_on_yo_momma }
          t.references :bar, index: { unique: true }
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_yo_momma)
        assert connection.index_exists?(table_name, :bar_id, name: :index_testings_on_bar_id, unique: true)
      end

      def test_creates_polymorphic_index
        connection.create_table table_name do |t|
          t.references :foo, polymorphic: true, index: true
        end

        assert connection.index_exists?(table_name, [:foo_type, :foo_id], name: :index_testings_on_foo)
      end

      def test_creates_polymorphic_index_with_custom_name
        connection.create_table table_name do |t|
          t.references :foo, polymorphic: true, index: { name: :testings_foo_index }
        end

        assert connection.index_exists?(table_name, [:foo_type, :foo_id], name: :testings_foo_index)
      end

      def test_creates_index_for_existing_table
        connection.create_table table_name
        connection.change_table table_name do |t|
          t.references :foo, index: true
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_creates_index_for_existing_table_even_if_index_option_is_not_passed
        connection.create_table table_name
        connection.change_table table_name do |t|
          t.references :foo
        end

        assert connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_does_not_create_index_for_existing_table_explicit
        connection.create_table table_name
        connection.change_table table_name do |t|
          t.references :foo, index: false
        end

        assert_not connection.index_exists?(table_name, :foo_id, name: :index_testings_on_foo_id)
      end

      def test_creates_polymorphic_index_for_existing_table
        connection.create_table table_name
        connection.change_table table_name do |t|
          t.references :foo, polymorphic: true, index: true
        end

        assert connection.index_exists?(table_name, [:foo_type, :foo_id], name: :index_testings_on_foo)
      end

      def test_creates_polymorphic_index_for_existing_table_with_custom_name
        connection.create_table table_name
        connection.change_table table_name do |t|
          t.references :foo, polymorphic: true, index: { name: :testings_foo_index }
        end

        assert connection.index_exists?(table_name, [:foo_type, :foo_id], name: :testings_foo_index)
      end
    end
  end
end
