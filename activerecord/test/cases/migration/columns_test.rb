# frozen_string_literal: true

require "cases/migration/helper"

module ActiveRecord
  class Migration
    class ColumnsTest < ActiveRecord::TestCase
      include ActiveRecord::Migration::TestHelper

      self.use_transactional_tests = false

      # FIXME: this is more of an integration test with AR::Base and the
      # schema modifications.  Maybe we should move this?
      def test_add_rename
        add_column "test_models", "girlfriend", :string
        TestModel.reset_column_information

        TestModel.create girlfriend: "bobette"

        rename_column "test_models", "girlfriend", "exgirlfriend"

        TestModel.reset_column_information
        bob = TestModel.first

        assert_equal "bobette", bob.exgirlfriend
      end

      # FIXME: another integration test.  We should decouple this from the
      # AR::Base implementation.
      def test_rename_column_using_symbol_arguments
        add_column :test_models, :first_name, :string

        TestModel.create first_name: "foo"

        rename_column :test_models, :first_name, :nick_name
        TestModel.reset_column_information
        assert_includes TestModel.column_names, "nick_name"
        assert_equal ["foo"], TestModel.all.map(&:nick_name)
      end

      # FIXME: another integration test.  We should decouple this from the
      # AR::Base implementation.
      def test_rename_column
        add_column "test_models", "first_name", "string"

        TestModel.create first_name: "foo"

        rename_column "test_models", "first_name", "nick_name"
        TestModel.reset_column_information
        assert_includes TestModel.column_names, "nick_name"
        assert_equal ["foo"], TestModel.all.map(&:nick_name)
      end

      def test_rename_column_preserves_default_value_not_null
        add_column "test_models", "salary", :integer, default: 70000

        default_before = connection.columns("test_models").find { |c| c.name == "salary" }.default
        assert_equal "70000", default_before

        rename_column "test_models", "salary", "annual_salary"

        assert_includes TestModel.column_names, "annual_salary"
        default_after = connection.columns("test_models").find { |c| c.name == "annual_salary" }.default
        assert_equal "70000", default_after
      end

      if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        def test_mysql_rename_column_preserves_auto_increment
          rename_column "test_models", "id", "id_test"
          assert_predicate connection.columns("test_models").find { |c| c.name == "id_test" }, :auto_increment?
          TestModel.reset_column_information
        ensure
          rename_column "test_models", "id_test", "id"
        end
      end

      def test_rename_nonexistent_column
        exception = if current_adapter?(:PostgreSQLAdapter)
          ActiveRecord::StatementInvalid
        else
          ActiveRecord::ActiveRecordError
        end

        assert_raise(exception) do
          rename_column "test_models", "nonexistent", "should_fail"
        end
      end

      def test_rename_column_with_sql_reserved_word
        add_column "test_models", "first_name", :string
        rename_column "test_models", "first_name", "group"

        assert_includes TestModel.column_names, "group"
      end

      def test_rename_column_with_an_index
        add_column "test_models", :hat_name, :string
        add_index :test_models, :hat_name

        assert_equal 1, connection.indexes("test_models").size
        rename_column "test_models", "hat_name", "name"

        assert_equal ["index_test_models_on_name"], connection.indexes("test_models").map(&:name)
      end

      def test_rename_column_with_multi_column_index
        add_column "test_models", :hat_size, :integer
        add_column "test_models", :hat_style, :string, limit: 100
        add_index "test_models", ["hat_style", "hat_size"], unique: true

        rename_column "test_models", "hat_size", "size"
        assert_equal ["index_test_models_on_hat_style_and_size"], connection.indexes("test_models").map(&:name)

        rename_column "test_models", "hat_style", "style"
        assert_equal ["index_test_models_on_style_and_size"], connection.indexes("test_models").map(&:name)
      end

      def test_rename_column_does_not_rename_custom_named_index
        add_column "test_models", :hat_name, :string
        add_index :test_models, :hat_name, name: "idx_hat_name"

        assert_equal 1, connection.indexes("test_models").size
        rename_column "test_models", "hat_name", "name"
        assert_equal ["idx_hat_name"], connection.indexes("test_models").map(&:name)
      end

      def test_remove_column_with_index
        add_column "test_models", :hat_name, :string
        add_index :test_models, :hat_name

        assert_equal 1, connection.indexes("test_models").size
        remove_column("test_models", "hat_name")
        assert_equal 0, connection.indexes("test_models").size
      end

      def test_remove_column_with_multi_column_index
        # MariaDB starting with 10.2.8
        # Dropping a column that is part of a multi-column UNIQUE constraint is not permitted.
        skip if current_adapter?(:Mysql2Adapter, :TrilogyAdapter) && connection.mariadb? && connection.database_version >= "10.2.8"

        add_column "test_models", :hat_size, :integer
        add_column "test_models", :hat_style, :string, limit: 100
        add_index "test_models", ["hat_style", "hat_size"], unique: true

        assert_equal 1, connection.indexes("test_models").size
        remove_column("test_models", "hat_size")

        # Every database and/or database adapter has their own behavior
        # if it drops the multi-column index when any of the indexed columns dropped by remove_column.
        if current_adapter?(:PostgreSQLAdapter)
          assert_equal [], connection.indexes("test_models").map(&:name)
        else
          assert_equal ["index_test_models_on_hat_style_and_hat_size"], connection.indexes("test_models").map(&:name)
        end
      end

      def test_change_type_of_not_null_column
        change_column "test_models", "updated_at", :datetime, null: false
        change_column "test_models", "updated_at", :datetime, null: false

        TestModel.reset_column_information
        assert_equal false, TestModel.columns_hash["updated_at"].null
      ensure
        change_column "test_models", "updated_at", :datetime, null: true
      end

      def test_change_column_nullability
        add_column "test_models", "funny", :boolean
        assert TestModel.columns_hash["funny"].null, "Column 'funny' must initially allow nulls"

        change_column "test_models", "funny", :boolean, null: false, default: true

        TestModel.reset_column_information
        assert_not TestModel.columns_hash["funny"].null, "Column 'funny' must *not* allow nulls at this point"

        change_column "test_models", "funny", :boolean, null: true
        TestModel.reset_column_information
        assert TestModel.columns_hash["funny"].null, "Column 'funny' must allow nulls again at this point"
      end

      def test_change_column
        add_column "test_models", "age", :integer
        add_column "test_models", "approved", :boolean, default: true

        old_columns = connection.columns(TestModel.table_name)

        assert old_columns.find { |c| c.name == "age" && c.type == :integer }

        change_column "test_models", "age", :string

        new_columns = connection.columns(TestModel.table_name)

        assert_not new_columns.find { |c| c.name == "age" && c.type == :integer }
        assert new_columns.find { |c| c.name == "age" && c.type == :string }

        old_columns = connection.columns(TestModel.table_name)
        assert old_columns.find { |c|
          default = c.fetch_cast_type(connection).deserialize(c.default)
          c.name == "approved" && c.type == :boolean && default == true
        }

        change_column :test_models, :approved, :boolean, default: false
        new_columns = connection.columns(TestModel.table_name)

        assert_not new_columns.find { |c|
          default = c.fetch_cast_type(connection).deserialize(c.default)
          c.name == "approved" && c.type == :boolean && default == true
        }
        assert new_columns.find { |c|
          default = c.fetch_cast_type(connection).deserialize(c.default)
          c.name == "approved" && c.type == :boolean && default == false
        }
        change_column :test_models, :approved, :boolean, default: true
      end

      def test_change_column_with_nil_default
        add_column "test_models", "contributor", :boolean, default: true
        assert_predicate TestModel.new, :contributor?

        change_column "test_models", "contributor", :boolean, default: nil
        TestModel.reset_column_information
        assert_not_predicate TestModel.new, :contributor?
        assert_nil TestModel.new.contributor
      end

      def test_change_column_to_drop_default_with_null_false
        add_column "test_models", "contributor", :boolean, default: true, null: false
        assert_predicate TestModel.new, :contributor?

        change_column "test_models", "contributor", :boolean, default: nil, null: false
        TestModel.reset_column_information
        assert_not_predicate TestModel.new, :contributor?
        assert_nil TestModel.new.contributor
      end

      def test_change_column_with_new_default
        add_column "test_models", "administrator", :boolean, default: true
        assert_predicate TestModel.new, :administrator?

        change_column "test_models", "administrator", :boolean, default: false
        TestModel.reset_column_information
        assert_not_predicate TestModel.new, :administrator?
      end

      def test_change_column_with_custom_index_name
        add_column "test_models", "category", :string
        add_index :test_models, :category, name: "test_models_categories_idx"

        assert_equal ["test_models_categories_idx"], connection.indexes("test_models").map(&:name)
        change_column "test_models", "category", :string, null: false, default: "article"

        assert_equal ["test_models_categories_idx"], connection.indexes("test_models").map(&:name)
      end

      def test_change_column_with_long_index_name
        table_name_prefix = "test_models_"
        long_index_name = table_name_prefix + ("x" * (connection.index_name_length - table_name_prefix.length))
        add_column "test_models", "category", :string
        add_index :test_models, :category, name: long_index_name

        change_column "test_models", "category", :string, null: false, default: "article"

        assert_equal [long_index_name], connection.indexes("test_models").map(&:name)
      end

      def test_change_column_default
        add_column "test_models", "first_name", :string
        connection.change_column_default "test_models", "first_name", "Tester"

        assert_equal "Tester", TestModel.new.first_name
      end

      def test_change_column_default_to_null
        add_column "test_models", "first_name", :string
        connection.change_column_default "test_models", "first_name", nil

        assert_nil TestModel.new.first_name
      end

      def test_change_column_default_to_null_with_not_null
        add_column "test_models", "first_name", :string, null: false
        add_column "test_models", "age", :integer, null: false

        connection.change_column_default "test_models", "first_name", nil

        assert_nil TestModel.new.first_name

        connection.change_column_default "test_models", "age", nil

        assert_nil TestModel.new.age
      end

      def test_change_column_default_with_from_and_to
        add_column "test_models", "first_name", :string
        connection.change_column_default "test_models", "first_name", from: nil, to: "Tester"

        assert_equal "Tester", TestModel.new.first_name
      end

      def test_change_column_default_preserves_existing_column_default_function
        skip unless current_adapter?(:SQLite3Adapter)

        connection.change_column_default "test_models", "created_at", -> { "CURRENT_TIMESTAMP" }
        TestModel.reset_column_information
        assert_equal "CURRENT_TIMESTAMP", TestModel.columns_hash["created_at"].default_function

        add_column "test_models", "edited_at", :datetime
        connection.change_column_default "test_models", "edited_at", -> { "CURRENT_TIMESTAMP" }
        TestModel.reset_column_information
        assert_equal "CURRENT_TIMESTAMP", TestModel.columns_hash["created_at"].default_function
        assert_equal "CURRENT_TIMESTAMP", TestModel.columns_hash["edited_at"].default_function
      end

      def test_change_column_default_supports_default_function_with_concatenation_operator
        skip unless current_adapter?(:SQLite3Adapter)

        add_column "test_models", "ruby_on_rails", :string
        connection.change_column_default "test_models", "ruby_on_rails", -> { "('Ruby ' || 'on ' || 'Rails')" }
        TestModel.reset_column_information
        assert_equal "'Ruby ' || 'on ' || 'Rails'", TestModel.columns_hash["ruby_on_rails"].default_function
      end

      def test_change_column_null_false
        add_column "test_models", "first_name", :string
        connection.change_column_null "test_models", "first_name", false

        assert_raise(ActiveRecord::NotNullViolation) do
          TestModel.create!(first_name: nil)
        end
      end

      def test_change_column_null_true
        add_column "test_models", "first_name", :string
        connection.change_column_null "test_models", "first_name", true

        assert_difference("TestModel.count" => 1) do
          TestModel.create!(first_name: nil)
        end
      end

      def test_change_column_null_with_non_boolean_arguments_raises
        add_column "test_models", "first_name", :string
        e = assert_raise(ArgumentError) do
          connection.change_column_null "test_models", "first_name", from: true, to: false
        end
        assert_equal "change_column_null expects a boolean value (true for NULL, false for NOT NULL). Got: #{{ from: true, to: false }}", e.message
      end

      def test_change_column_null_does_not_change_default_functions
        skip unless current_adapter?(:Mysql2Adapter, :TrilogyAdapter) && supports_default_expression?

        function = connection.mariadb? ? "current_timestamp(6)" : "(now())"

        connection.change_column_default "test_models", "created_at", -> { function }
        TestModel.reset_column_information
        assert_equal function, TestModel.columns_hash["created_at"].default_function

        connection.change_column_null "test_models", "created_at", true
        TestModel.reset_column_information
        assert_equal function, TestModel.columns_hash["created_at"].default_function
      end

      def test_remove_column_no_second_parameter_raises_exception
        assert_raise(ArgumentError) { connection.remove_column("funny") }
      end

      def test_removing_and_renaming_column_preserves_custom_primary_key
        connection.create_table "my_table", primary_key: "my_table_id", force: true do |t|
          t.integer "col_one"
          t.string "col_two", limit: 128, null: false
        end

        remove_column("my_table", "col_two")
        rename_column("my_table", "col_one", "col_three")

        assert_equal "my_table_id", connection.primary_key("my_table")
      ensure
        connection.drop_table(:my_table) rescue nil
      end

      def test_column_with_index
        connection.create_table "my_table", force: true do |t|
          t.string :item_number, index: true
        end

        assert connection.index_exists?("my_table", :item_number, name: :index_my_table_on_item_number)
      ensure
        connection.drop_table(:my_table) rescue nil
      end

      def test_add_column_without_column_name
        e = assert_raise ArgumentError do
          connection.create_table "my_table", force: true do |t|
            t.timestamp
          end
        end
        assert_equal "Missing column name(s) for timestamp", e.message
      ensure
        connection.drop_table :my_table, if_exists: true
      end

      def test_remove_columns_single_statement
        connection.create_table "my_table" do |t|
          t.integer "col_one"
          t.integer "col_two"
        end

        # SQLite3's ALTER TABLE statement has several limitations. To manage
        # this, the adapter creates a temporary table, copies the data, drops
        # the old table, creates the new table, then copies the data back.
        expected_query_count = current_adapter?(:SQLite3Adapter) ? 14 : 1
        assert_queries_count(expected_query_count) do
          connection.remove_columns("my_table", "col_one", "col_two")
        end

        columns = connection.columns("my_table").map(&:name)
        assert_equal ["id"], columns
      ensure
        connection.drop_table :my_table, if_exists: true
      end

      def test_add_timestamps_single_statement
        connection.create_table "my_table"

        # SQLite3's ALTER TABLE statement has several limitations. To manage
        # this, the adapter creates a temporary table, copies the data, drops
        # the old table, creates the new table, then copies the data back.
        expected_query_count = current_adapter?(:SQLite3Adapter) ? 14 : 1
        assert_queries_count(expected_query_count) do
          connection.add_timestamps("my_table")
        end

        columns = connection.columns("my_table").map(&:name)
        assert_equal ["id", "created_at", "updated_at"], columns
      ensure
        connection.drop_table :my_table, if_exists: true
      end
    end
  end
end
