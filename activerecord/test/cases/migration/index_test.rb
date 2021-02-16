# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class IndexTest < ActiveRecord::TestCase
      attr_reader :connection, :table_name

      def setup
        super
        @connection = ActiveRecord::Base.connection
        @table_name = :testings

        connection.create_table table_name do |t|
          t.column :foo, :string, limit: 100
          t.column :bar, :string, limit: 100

          # mimic a foreign key
          t.column :key_1, :string, limit: 100
          t.column :key_2, :string, limit: 100

          t.string :first_name
          t.string :last_name, limit: 100
          t.string :key,       limit: 100
          t.boolean :administrator
        end
      end

      teardown do
        connection.drop_table :testings rescue nil
        ActiveRecord::Base.primary_key_prefix_type = nil
      end

      def test_rename_index
        # keep the names short to make Oracle and similar behave
        connection.add_index(table_name, [:foo], name: "old_idx")
        connection.rename_index(table_name, "old_idx", "new_idx")

        assert_not connection.index_name_exists?(table_name, "old_idx")
        assert connection.index_name_exists?(table_name, "new_idx")
      end

      def test_rename_index_with_symbol
        # keep the names short to make Oracle and similar behave
        connection.add_index(table_name, [:foo], name: :old_idx)
        connection.rename_index(table_name, :old_idx, :new_idx)

        assert_not connection.index_name_exists?(table_name, "old_idx")
        assert connection.index_name_exists?(table_name, "new_idx")
      end

      def test_rename_index_too_long
        too_long_index_name = good_index_name + "x"
        # keep the names short to make Oracle and similar behave
        connection.add_index(table_name, [:foo], name: "old_idx")
        e = assert_raises(ArgumentError) {
          connection.rename_index(table_name, "old_idx", too_long_index_name)
        }
        assert_match(/too long; the limit is #{connection.index_name_length} characters/, e.message)

        assert connection.index_name_exists?(table_name, "old_idx")
      end

      def test_remove_nonexistent_index
        assert_raise(ArgumentError) { connection.remove_index(table_name, "no_such_index") }
      end

      def test_add_index_works_with_long_index_names
        connection.add_index(table_name, "foo", name: good_index_name)

        assert connection.index_name_exists?(table_name, good_index_name)
        connection.remove_index(table_name, name: good_index_name)
      end

      def test_add_index_does_not_accept_too_long_index_names
        too_long_index_name = good_index_name + "x"

        e = assert_raises(ArgumentError) {
          connection.add_index(table_name, "foo", name: too_long_index_name)
        }
        assert_match(/too long; the limit is #{connection.index_name_length} characters/, e.message)

        assert_not connection.index_name_exists?(table_name, too_long_index_name)
        connection.add_index(table_name, "foo", name: good_index_name)
      end

      def test_add_index_which_already_exists_does_not_raise_error_with_option
        connection.add_index(table_name, "foo")

        assert_nothing_raised do
          connection.add_index(table_name, "foo", if_not_exists: true)
        end

        assert connection.index_name_exists?(table_name, "index_testings_on_foo")
      end

      def test_add_index_with_if_not_exists_matches_exact_index
        connection.add_index(table_name, [:foo, :bar], unique: false, name: "index_testings_on_foo_bar")

        assert connection.index_name_exists?(table_name, "index_testings_on_foo_bar")

        assert_nothing_raised do
          connection.add_index(table_name, [:foo, :bar], unique: true, if_not_exists: true)
        end

        assert connection.index_name_exists?(table_name, "index_testings_on_foo_and_bar")
      end

      def test_remove_index_which_does_not_exist_doesnt_raise_with_option
        connection.add_index(table_name, "foo")

        connection.remove_index(table_name, "foo")

        assert_raises ArgumentError do
          connection.remove_index(table_name, "foo")
        end

        assert_nothing_raised do
          connection.remove_index(table_name, "foo", if_exists: true)
        end
      end

      def test_remove_index_with_name_which_does_not_exist_doesnt_raise_with_option
        connection.add_index(table_name, [:foo], name: "foo")

        assert connection.index_exists?(table_name, :foo, name: "foo")

        connection.remove_index(table_name, nil, name: "foo", if_exists: true)

        assert_not connection.index_exists?(table_name, :foo, name: "foo")
      end

      def test_internal_index_with_name_matching_database_limit
        good_index_name = "x" * connection.index_name_length
        connection.add_index(table_name, "foo", name: good_index_name, internal: true)

        assert connection.index_name_exists?(table_name, good_index_name)
        connection.remove_index(table_name, name: good_index_name)
      end

      def test_index_symbol_names
        connection.add_index table_name, :foo, name: :symbol_index_name
        assert connection.index_exists?(table_name, :foo, name: :symbol_index_name)

        connection.remove_index table_name, name: :symbol_index_name
        assert_not connection.index_exists?(table_name, :foo, name: :symbol_index_name)
      end

      def test_index_exists
        connection.add_index :testings, :foo

        assert connection.index_exists?(:testings, :foo)
        assert_not connection.index_exists?(:testings, :bar)
      end

      def test_index_exists_on_multiple_columns
        connection.add_index :testings, [:foo, :bar]

        assert connection.index_exists?(:testings, [:foo, :bar])
      end

      def test_index_exists_with_custom_name_checks_columns
        connection.add_index :testings, [:foo, :bar], name: "my_index"
        assert connection.index_exists?(:testings, [:foo, :bar], name: "my_index")
        assert_not connection.index_exists?(:testings, [:foo], name: "my_index")
      end

      def test_valid_index_options
        assert_raise ArgumentError do
          connection.add_index :testings, :foo, unqiue: true
        end
      end

      def test_unique_index_exists
        connection.add_index :testings, :foo, unique: true

        assert connection.index_exists?(:testings, :foo, unique: true)
      end

      def test_named_index_exists
        connection.add_index :testings, :foo, name: "custom_index_name"

        assert connection.index_exists?(:testings, :foo)
        assert connection.index_exists?(:testings, :foo, name: "custom_index_name")
        assert_not connection.index_exists?(:testings, :foo, name: "other_index_name")
      end

      def test_remove_named_index
        connection.add_index :testings, :foo, name: "index_testings_on_custom_index_name"

        assert connection.index_exists?(:testings, :foo)

        assert_raise(ArgumentError) { connection.remove_index(:testings, "custom_index_name") }

        connection.remove_index :testings, :foo
        assert_not connection.index_exists?(:testings, :foo)
      end

      def test_add_index_attribute_length_limit
        connection.add_index :testings, [:foo, :bar], length: { foo: 10, bar: nil }

        assert connection.index_exists?(:testings, [:foo, :bar])
      end

      def test_add_index_foreign_keys_appends_id_to_foreign_keys
        connection.add_index :testings, [:key_1, :key_2], foreign_keys: true, length: 10

        assert connection.index_exists?(:testings, [:key_1, :key_2])
      end

      def test_add_index_foreign_keys_appends_id_to_foreign_keys_will_fail_if_no_related_belongs_to_column_exists
        assert_raise(ArgumentError) do
          connection.add_index :testings, [:foo, :bar], foreign_keys: true
        end
      end

      def test_add_index
        connection.add_index("testings", "last_name")
        connection.remove_index("testings", "last_name")

        connection.add_index("testings", ["last_name", "first_name"])
        connection.remove_index("testings", column: ["last_name", "first_name"])

        connection.add_index("testings", ["last_name", "first_name"])
        connection.remove_index("testings", name: :index_testings_on_last_name_and_first_name)
        connection.add_index("testings", ["last_name", "first_name"])
        connection.remove_index("testings", "last_name_and_first_name")

        connection.add_index("testings", ["last_name", "first_name"])
        connection.remove_index("testings", ["last_name", "first_name"])

        connection.add_index("testings", ["last_name"], length: 10)
        connection.remove_index("testings", "last_name")

        connection.add_index("testings", ["last_name"], length: { last_name: 10 })
        connection.remove_index("testings", ["last_name"])

        connection.add_index("testings", ["last_name", "first_name"], length: 10)
        connection.remove_index("testings", ["last_name", "first_name"])

        connection.add_index("testings", ["last_name", "first_name"], length: { last_name: 10, first_name: 20 })
        connection.remove_index("testings", ["last_name", "first_name"])

        connection.add_index("testings", "key", unique: true)
        connection.remove_index("testings", "key", unique: true)

        connection.add_index("testings", ["key"], name: "key_idx", unique: true)
        connection.remove_index("testings", name: "key_idx", unique: true)

        connection.add_index("testings", %w(last_name first_name administrator), name: "named_admin")
        connection.remove_index("testings", name: "named_admin")

        # Selected adapters support index sort order
        if current_adapter?(:SQLite3Adapter, :Mysql2Adapter, :PostgreSQLAdapter)
          connection.add_index("testings", ["last_name"], order: { last_name: :desc })
          connection.remove_index("testings", ["last_name"])
          connection.add_index("testings", ["last_name", "first_name"], order: { last_name: :desc })
          connection.remove_index("testings", ["last_name", "first_name"])
          connection.add_index("testings", ["last_name", "first_name"], order: { last_name: :desc, first_name: :asc })
          connection.remove_index("testings", ["last_name", "first_name"])
          connection.add_index("testings", ["last_name", "first_name"], order: :desc)
          connection.remove_index("testings", ["last_name", "first_name"])
        end
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_add_partial_index
          connection.add_index("testings", "last_name", where: "first_name = 'john doe'")
          assert connection.index_exists?("testings", "last_name")

          connection.remove_index("testings", "last_name")
          assert_not connection.index_exists?("testings", "last_name")
        end
      end

      private
        def good_index_name
          "x" * connection.index_name_length
        end
    end
  end
end
