require 'cases/helper'

module ActiveRecord
  class Migration
    class IndexTest < ActiveRecord::TestCase
      attr_reader :connection, :table_name

      def setup
        super
        @connection = ActiveRecord::Base.connection
        @table_name = :testings

        connection.create_table table_name do |t|
          t.column :foo, :string, :limit => 100
          t.column :bar, :string, :limit => 100
        end
      end

      def teardown
        super
        connection.drop_table :testings rescue nil
        ActiveRecord::Base.primary_key_prefix_type = nil
      end

      def test_rename_index
        skip "not supported on openbase" if current_adapter?(:OpenBaseAdapter)

        # keep the names short to make Oracle and similar behave
        connection.add_index(table_name, [:foo], :name => 'old_idx')
        connection.rename_index(table_name, 'old_idx', 'new_idx')

        # if the adapter doesn't support the indexes call, pick defaults that let the test pass
        refute connection.index_name_exists?(table_name, 'old_idx', false)
        assert connection.index_name_exists?(table_name, 'new_idx', true)
      end

      def test_double_add_index
        skip "not supported on openbase" if current_adapter?(:OpenBaseAdapter)

        connection.add_index(table_name, [:foo], :name => 'some_idx')
        assert_raises(ArgumentError) {
          connection.add_index(table_name, [:foo], :name => 'some_idx')
        }
      end

      def test_remove_nonexistent_index
        skip "not supported on openbase" if current_adapter?(:OpenBaseAdapter)

        # we do this by name, so OpenBase is a wash as noted above
        assert_raise(ArgumentError) { connection.remove_index(table_name, "no_such_index") }
      end

      def test_add_index_length_limit
        good_index_name = 'x' * connection.index_name_length
        too_long_index_name = good_index_name + 'x'

        assert_raises(ArgumentError) {
          connection.add_index(table_name, "foo", :name => too_long_index_name)
        }

        refute connection.index_name_exists?(table_name, too_long_index_name, false)
        connection.add_index(table_name, "foo", :name => good_index_name)

        assert connection.index_name_exists?(table_name, good_index_name, false)
        connection.remove_index(table_name, :name => good_index_name)
      end

      def test_index_symbol_names
        connection.add_index table_name, :foo, :name => :symbol_index_name
        assert connection.index_exists?(table_name, :foo, :name => :symbol_index_name)

        connection.remove_index table_name, :name => :symbol_index_name
        refute connection.index_exists?(table_name, :foo, :name => :symbol_index_name)
      end

      def test_index_exists
        connection.add_index :testings, :foo

        assert connection.index_exists?(:testings, :foo)
        assert !connection.index_exists?(:testings, :bar)
      end

      def test_index_exists_on_multiple_columns
        connection.add_index :testings, [:foo, :bar]

        assert connection.index_exists?(:testings, [:foo, :bar])
      end

      def test_unique_index_exists
        connection.add_index :testings, :foo, :unique => true

        assert connection.index_exists?(:testings, :foo, :unique => true)
      end

      def test_named_index_exists
        connection.add_index :testings, :foo, :name => "custom_index_name"

        assert connection.index_exists?(:testings, :foo, :name => "custom_index_name")
      end
    end
  end
end
