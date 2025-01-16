# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

module ActiveRecord
  class Migration
    class CompatibilityTest < ActiveRecord::TestCase
      attr_reader :connection
      self.use_transactional_tests = false

      class TestModel < ActiveRecord::Base
        self.table_name = :testings
      end

      def setup
        super
        @connection = ActiveRecord::Base.lease_connection
        @pool = ActiveRecord::Base.connection_pool
        @schema_migration = @pool.schema_migration
        @internal_metadata = @pool.internal_metadata
        @verbose_was = ActiveRecord::Migration.verbose
        ActiveRecord::Migration.verbose = false

        connection.create_table :testings do |t|
          t.column :foo, :string, limit: 5
          t.column :bar, :string, limit: 100
        end
      end

      teardown do
        connection.drop_table :testings rescue nil
        ActiveRecord::Migration.verbose = @verbose_was
        @schema_migration.delete_all_versions rescue nil
      end

      def test_migration_doesnt_remove_named_index
        connection.add_index :testings, :foo, name: "custom_index_name"

        migration = Class.new(ActiveRecord::Migration[4.2]) {
          def version; 101 end
          def migrate(x)
            remove_index :testings, :foo
          end
        }.new

        assert connection.index_exists?(:testings, :foo, name: "custom_index_name")
        assert_raise(StandardError) { ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate }
        assert connection.index_exists?(:testings, :foo, name: "custom_index_name")
      end

      def test_migration_does_remove_unnamed_index
        connection.add_index :testings, :bar

        migration = Class.new(ActiveRecord::Migration[4.2]) {
          def version; 101 end
          def migrate(x)
            remove_index :testings, :bar
          end
        }.new

        assert connection.index_exists?(:testings, :bar)
        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
        assert_not connection.index_exists?(:testings, :bar)
      end

      def test_references_does_not_add_index_by_default
        migration = Class.new(ActiveRecord::Migration[4.2]) {
          def migrate(x)
            create_table :more_testings do |t|
              t.references :foo
              t.belongs_to :bar, index: false
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert_not connection.index_exists?(:more_testings, :foo_id)
        assert_not connection.index_exists?(:more_testings, :bar_id)
      ensure
        connection.drop_table :more_testings rescue nil
      end

      def test_timestamps_have_null_constraints_if_not_present_in_migration_of_create_table
        migration = Class.new(ActiveRecord::Migration[4.2]) {
          def migrate(x)
            create_table :more_testings do |t|
              t.timestamps
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:more_testings, :created_at, null: true)
        assert connection.column_exists?(:more_testings, :updated_at, null: true)
      ensure
        connection.drop_table :more_testings rescue nil
      end

      def test_timestamps_have_null_constraints_if_not_present_in_migration_of_change_table
        migration = Class.new(ActiveRecord::Migration[4.2]) {
          def migrate(x)
            change_table :testings do |t|
              t.timestamps
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:testings, :created_at, null: true)
        assert connection.column_exists?(:testings, :updated_at, null: true)
      end

      if ActiveRecord::Base.lease_connection.supports_bulk_alter?
        def test_timestamps_have_null_constraints_if_not_present_in_migration_of_change_table_with_bulk
          migration = Class.new(ActiveRecord::Migration[4.2]) {
            def migrate(x)
              change_table :testings, bulk: true do |t|
                t.timestamps
              end
            end
          }.new

          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

          assert connection.column_exists?(:testings, :created_at, null: true)
          assert connection.column_exists?(:testings, :updated_at, null: true)
        end
      end

      def test_timestamps_have_null_constraints_if_not_present_in_migration_for_adding_timestamps_to_existing_table
        migration = Class.new(ActiveRecord::Migration[4.2]) {
          def migrate(x)
            add_timestamps :testings
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:testings, :created_at, null: true)
        assert connection.column_exists?(:testings, :updated_at, null: true)
      end

      def test_timestamps_doesnt_set_precision_on_create_table
        migration = Class.new(ActiveRecord::Migration[5.2]) {
          def migrate(x)
            create_table :more_testings do |t|
              t.timestamps
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:more_testings, :created_at, null: false, **precision_implicit_default)
        assert connection.column_exists?(:more_testings, :updated_at, null: false, **precision_implicit_default)
      ensure
        connection.drop_table :more_testings rescue nil
      end

      def test_timestamps_doesnt_set_precision_on_change_table
        migration = Class.new(ActiveRecord::Migration[5.2]) {
          def migrate(x)
            change_table :testings do |t|
              t.timestamps default: Time.now
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:testings, :created_at, null: false, **precision_implicit_default)
        assert connection.column_exists?(:testings, :updated_at, null: false, **precision_implicit_default)
      end

      if ActiveRecord::Base.lease_connection.supports_bulk_alter?
        def test_timestamps_doesnt_set_precision_on_change_table_with_bulk
          migration = Class.new(ActiveRecord::Migration[5.2]) {
            def migrate(x)
              change_table :testings, bulk: true do |t|
                t.timestamps
              end
            end
          }.new

          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

          assert connection.column_exists?(:testings, :created_at, null: false, **precision_implicit_default)
          assert connection.column_exists?(:testings, :updated_at, null: false, **precision_implicit_default)
        end
      end

      def test_timestamps_doesnt_set_precision_on_add_timestamps
        migration = Class.new(ActiveRecord::Migration[5.2]) {
          def migrate(x)
            add_timestamps :testings, default: Time.now
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:testings, :created_at, null: false, **precision_implicit_default)
        assert connection.column_exists?(:testings, :updated_at, null: false, **precision_implicit_default)
      end

      def test_legacy_migrations_raises_exception_when_inherited
        e = assert_raises(StandardError) do
          class_eval("class LegacyMigration < ActiveRecord::Migration; end")
        end
        assert_match(/LegacyMigration < ActiveRecord::Migration\[\d\.\d\]/, e.message)
      end

      def test_legacy_migrations_not_raise_exception_on_reverting_transaction
        migration = Class.new(ActiveRecord::Migration[5.2]) {
          def change
            transaction do
              execute "select 1"
            end
          end
        }.new

        assert_nothing_raised do
          migration.migrate(:down)
        end
      end

      if ActiveRecord::Base.lease_connection.supports_comments?
        def test_change_column_comment_can_be_reverted
          migration = Class.new(ActiveRecord::Migration[5.2]) {
            def migrate(x)
              revert do
                change_column_comment(:testings, :foo, "comment")
              end
            end
          }.new

          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
          assert connection.column_exists?(:testings, :foo, comment: "comment")
        end

        def test_change_table_comment_can_be_reverted
          migration = Class.new(ActiveRecord::Migration[5.2]) {
            def migrate(x)
              revert do
                change_table_comment(:testings, "comment")
              end
            end
          }.new

          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

          assert_equal "comment", connection.table_comment("testings")
        end
      end

      def test_create_table_allows_duplicate_column_names
        migration = Class.new(ActiveRecord::Migration[5.2]) {
          def migrate(x)
            create_table :tests do |t|
              t.integer :some_id
              t.string :some_id
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        column = connection.columns(:tests).find { |column| column.name == "some_id" }
        assert_equal :string, column.type
      ensure
        connection.drop_table :tests, if_exists: true
      end

      if current_adapter?(:PostgreSQLAdapter)
        class Testing < ActiveRecord::Base
        end

        def test_legacy_change_column_with_null_executes_update
          migration = Class.new(ActiveRecord::Migration[5.1]) {
            def migrate(x)
              change_column :testings, :foo, :string, limit: 10, null: false, default: "foobar"
            end
          }.new

          Testing.create!
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
          assert_equal ["foobar"], Testing.all.map(&:foo)
        ensure
          ActiveRecord::Base.clear_cache!
        end
      end

      def test_timestamps_sets_default_precision_on_create_table
        migration = Class.new(ActiveRecord::Migration[6.1]) {
          def migrate(x)
            create_table :more_testings do |t|
              t.timestamps
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:more_testings, :created_at, precision: 6)
        assert connection.column_exists?(:more_testings, :updated_at, precision: 6)
      ensure
        connection.drop_table :more_testings rescue nil
      end

      def test_datetime_doesnt_set_precision_on_add_column_5_0
        migration = Class.new(ActiveRecord::Migration[5.0]) {
          def migrate(x)
            add_column :testings, :published_at, :datetime, default: Time.now
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:testings, :published_at, **precision_implicit_default)
      end

      def test_datetime_doesnt_set_precision_on_add_column_6_1
        migration = Class.new(ActiveRecord::Migration[6.1]) {
          def migrate(x)
            add_column :testings, :published_at, :datetime, default: Time.now
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:testings, :published_at, **precision_implicit_default)
      end

      def test_change_table_allows_if_exists_option_on_7_0
        migration = Class.new(ActiveRecord::Migration[7.0]) {
          def migrate(x)
            change_table(:testings) do |t|
              t.remove :foo, if_exists: true
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert_not connection.column_exists?(:testings, :foo)
      end

      def test_add_reference_allows_if_exists_option_on_7_0
        migration = Class.new(ActiveRecord::Migration[7.0]) {
          def migrate(x)
            add_reference :testings, :widget, if_not_exists: true
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        assert connection.column_exists?(:testings, :widget_id)
      end

      def test_references_on_create_table_on_6_0
        migration = Class.new(ActiveRecord::Migration[6.0]) {
          def migrate(x)
            create_table :more_testings do |t|
              t.references :testings
            end
          end
        }.new

        ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

        column = connection.columns(:more_testings).find { |el| el.name == "testings_id" }

        if current_adapter?(:SQLite3Adapter)
          assert_match(/integer/i, column.sql_type)
        else
          assert_predicate(column, :bigint?)
        end
      ensure
        connection.drop_table :more_testings rescue nil
      end

      def test_add_index_errors_on_too_long_name_7_0
        migration = Class.new(ActiveRecord::Migration[7.0]) {
          def migrate(x)
            add_column :testings, :very_long_column_name_to_test_with, :string
            add_index :testings, [:foo, :bar, :very_long_column_name_to_test_with]
          end
        }.new

        error = assert_raises(StandardError) do
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
        end

        assert_match(/index_testings_on_foo_and_bar_and_very_long_column_name_to_test_with/i, error.message)
        assert_match(/is too long/i, error.message)
      end

      def test_create_table_add_index_errors_on_too_long_name_7_0
        migration = Class.new(ActiveRecord::Migration[7.0]) {
          def migrate(x)
            create_table :more_testings do |t|
              t.integer :foo
              t.integer :bar
              t.integer :very_long_column_name_to_test_with
              t.index [:foo, :bar, :very_long_column_name_to_test_with]
            end
          end
        }.new

        error = assert_raises(StandardError) do
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
        end

        assert_match(/index_more_testings_on_foo_and_bar_and_very_long_column_name_to_test_with/i, error.message)
        assert_match(/is too long/i, error.message)
      ensure
        connection.drop_table :more_testings rescue nil
      end

      def test_rename_table_errors_on_too_long_index_name_7_0
        long_table_name = "a" * connection.table_name_length

        migration = Class.new(ActiveRecord::Migration[7.0]) {
          def migrate(x)
            add_index :testings, :foo
            long_table_name = "a" * connection.table_name_length
            rename_table :testings, long_table_name
          end
        }.new

        error = assert_raises(StandardError) do
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
        end

        assert_match(/index_#{long_table_name}_on_foo/i, error.message)
        assert_match(/is too long/i, error.message)
      ensure
        connection.drop_table long_table_name, if_exists: true
      end

      if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        def test_change_table_collation_not_unset_7_0
          migration = Class.new(ActiveRecord::Migration[7.0]) {
            def migrate(x)
              add_column :testings, :txt_collated, :string, charset: "utf8mb4", collation: "utf8mb4_general_ci"
              change_column :testings, :txt_collated, :string, default: "hi", collation: "utf8mb4_esperanto_ci"
            end
          }.new
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
          column = @connection.columns(:testings).find { |c| c.name == "txt_collated" }
          assert_equal "hi", column.default
          assert_equal "utf8mb4_esperanto_ci", column.collation
        end
      end

      def test_add_reference_on_6_0
        create_migration = Class.new(ActiveRecord::Migration[6.0]) {
          def version; 100 end
          def migrate(x)
            create_table :more_testings do |t|
              t.string :test
            end
          end
        }.new

        migration = Class.new(ActiveRecord::Migration[6.0]) {
          def version; 101 end
          def migrate(x)
            add_reference :more_testings, :testings
          end
        }.new

        ActiveRecord::Migrator.new(:up, [create_migration, migration], @schema_migration, @internal_metadata).migrate

        column = connection.columns(:more_testings).find { |el| el.name == "testings_id" }

        if current_adapter?(:SQLite3Adapter)
          assert_match(/integer/i, column.sql_type)
        else
          assert_predicate(column, :bigint?)
        end
      ensure
        connection.drop_table :more_testings rescue nil
      end

      def test_create_table_on_7_0
        long_table_name = "a" * (connection.table_name_length + 1)
        migration = Class.new(ActiveRecord::Migration[7.0]) {
          @@long_table_name = long_table_name
          def version; 100 end
          def migrate(x)
            create_table @@long_table_name
          end
        }.new

        if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
          # MySQL does not allow to create table names longer than limit
          error = assert_raises(StandardError) do
            ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
          end
          if connection.mariadb?
            assert_match(/Incorrect table name '#{long_table_name}'/i, error.message)
          else
            assert_match(/Identifier name '#{long_table_name}' is too long/i, error.message)
          end
        else
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
          assert connection.table_exists?(long_table_name)
        end
      ensure
        connection.drop_table(long_table_name) rescue nil
      end

      def test_rename_table_on_7_0
        long_table_name = "a" * (connection.table_name_length + 1)
        connection.create_table(:more_testings)

        migration = Class.new(ActiveRecord::Migration[7.0]) {
          @@long_table_name = long_table_name
          def version; 100 end
          def migrate(x)
            rename_table :more_testings, @@long_table_name
          end
        }.new

        if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
          # MySQL does not allow to create table names longer than limit
          error = assert_raises(StandardError) do
            ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
          end
          if connection.mariadb?
            assert_match(/Incorrect table name '#{long_table_name}'/i, error.message)
          else
            assert_match(/Identifier name '#{long_table_name}' is too long/i, error.message)
          end
        else
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
          assert connection.table_exists?(long_table_name)
          assert_not connection.table_exists?(:more_testings)
          assert connection.table_exists?(long_table_name)
        end
      ensure
        connection.drop_table(:more_testings) rescue nil
        connection.drop_table(long_table_name) rescue nil
      end

      def test_invert_rename_table_on_7_0
        connection.create_table(:more_testings)

        migration = Class.new(ActiveRecord::Migration[7.0]) {
          def change
            rename_table :more_testings, :new_more_testings
          end
        }.new

        migration.migrate(:up)
        assert connection.table_exists?(:new_more_testings)
        assert_not connection.table_exists?(:more_testings)

        migration.migrate(:down)
        assert_not connection.table_exists?(:new_more_testings)
        assert connection.table_exists?(:more_testings)
      ensure
        connection.drop_table(:more_testings) rescue nil
        connection.drop_table(:new_more_testings) rescue nil
      end

      def test_change_column_null_with_non_boolean_arguments_raises_in_a_migration
        migration = Class.new(ActiveRecord::Migration[7.1]) do
          def up
            add_column :testings, :name, :string
            change_column_null :testings, :name, from: true, to: false
          end
        end
        e = assert_raise(StandardError) do
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
        end
        assert_includes e.message, "change_column_null expects a boolean value (true for NULL, false for NOT NULL). Got: #{{ from: true, to: false }}"
      end

      def test_change_column_null_with_non_boolean_arguments_does_not_raise_in_old_rails_versions
        migration = Class.new(ActiveRecord::Migration[7.0]) do
          def up
            add_column :testings, :name, :string
            change_column_null :testings, :name, from: true, to: false
          end
        end
        assert_nothing_raised do
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
        end
        assert_difference("TestModel.count" => 1) do
          TestModel.create!(name: nil)
        end
      end

      def test_change_column_null_with_boolean_arguments_does_not_raise_in_old_rails_versions
        migration = Class.new(ActiveRecord::Migration[7.0]) do
          def up
            add_column :testings, :name, :string
            change_column_null :testings, :name, false
          end
        end
        assert_nothing_raised do
          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
        end
        assert_raise(ActiveRecord::NotNullViolation) do
          TestModel.create!(name: nil)
        end
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_disable_extension_on_7_0
          enable_extension!(:hstore, connection)

          migration = Class.new(ActiveRecord::Migration[7.0]) do
            def up
              add_column :testings, :settings, :hstore
              disable_extension :hstore
            end
          end

          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
          assert_not connection.extension_enabled?(:hstore)
        ensure
          disable_extension!(:hstore, connection)
        end

        def test_legacy_add_foreign_key_with_deferrable_true
          migration = Class.new(ActiveRecord::Migration[7.0]) {
            def migrate(x)
              create_table :sub_testings do |t|
                t.bigint :testing_id
              end

              add_foreign_key(:sub_testings, :testings, name: "deferrable_foreign_key", deferrable: true)
            end
          }.new

          ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

          foreign_keys = Testing.lease_connection.foreign_keys("sub_testings")
          assert_equal 1, foreign_keys.size
          assert_equal :immediate, foreign_keys.first.deferrable
        ensure
          connection.drop_table(:sub_testings, if_exists: true)
          ActiveRecord::Base.clear_cache!
        end
      end

      if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        def test_change_column_on_7_0
          migration = Class.new(ActiveRecord::Migration[7.0]) do
            def up
              execute("ALTER TABLE testings CONVERT TO CHARACTER SET utf32")
              change_column(:testings, :foo, "varchar(255) CHARACTER SET ascii")
            end
          end
          assert_nothing_raised do
            ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate
          end
        end
      end

      private
        def precision_implicit_default
          if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
            { precision: 0 }
          else
            { precision: nil }
          end
        end
    end
  end
end

module NoOptionValidationTestCases
  def test_options_are_not_validated
    migration = Class.new(migration_class) {
      def migrate(x)
        create_table :tests, wrong_id: false do |t|
          t.references :some_table, wrong_primary_key: true
          t.integer :some_id, wrong_unique: true
          t.string :some_string_column, wrong_null: false
        end

        add_column :tests, "last_name", :string, wrong_precision: true

        change_column :tests, :some_id, :float, wrong_index: true

        add_reference :tests, :another_table, invalid_option: :something

        change_table :tests do |t|
          t.change :some_id, :float, null: false, wrong_index: true
          t.integer :another_id, wrong_unique: true
          t.references :yet_another_table, bad: :option
        end
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

    assert connection.table_exists?(:tests)
  ensure
    connection.drop_table :tests, if_exists: true
  end
end

module DefaultPrecisionImplicitTestCases
  def test_datetime_doesnt_set_precision_on_change_table
    create_migration = Class.new(migration_class) {
      def migrate(x)
        create_table :more_testings do |t|
          t.datetime :published_at
        end
      end
    }.new(nil, 1)

    change_migration = Class.new(migration_class) {
      def migrate(x)
        change_table :more_testings do |t|
          t.change :published_at, :datetime, default: Time.now
        end
      end
    }.new(nil, 2)

    ActiveRecord::Migrator.new(:up, [create_migration, change_migration], @schema_migration, @internal_metadata).migrate

    assert connection.column_exists?(:more_testings, :published_at, **precision_implicit_default)
  ensure
    connection.drop_table :more_testings rescue nil
  end

  def test_datetime_doesnt_set_precision_on_create_table
    migration = Class.new(migration_class) {
      def migrate(x)
        create_table :more_testings do |t|
          t.datetime :published_at
        end
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

    assert connection.column_exists?(:more_testings, :published_at, **precision_implicit_default)
  ensure
    connection.drop_table :more_testings rescue nil
  end

  def test_datetime_doesnt_set_precision_on_change_column
    create_migration = Class.new(migration_class) {
      def migrate(x)
        create_table :more_testings do |t|
          t.date :published_at
        end
      end
    }.new(nil, 0)

    change_migration = Class.new(migration_class) {
      def migrate(x)
        change_column :more_testings, :published_at, :datetime
      end
    }.new(nil, 1)

    ActiveRecord::Migrator.new(:up, [create_migration, change_migration], @schema_migration, @internal_metadata).migrate

    assert connection.column_exists?(:more_testings, :published_at, **precision_implicit_default)
  ensure
    connection.drop_table :more_testings rescue nil
  end

  private
    def precision_implicit_default
      if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        { precision: 0 }
      else
        { precision: nil }
      end
    end
end

module DefaultPrecisionSixTestCases
  def test_datetime_sets_precision_6_on_change_table
    create_migration = Class.new(migration_class) {
      def migrate(x)
        create_table :more_testings do |t|
          t.datetime :published_at
        end
      end
    }.new(nil, 1)

    change_migration = Class.new(migration_class) {
      def migrate(x)
        change_table :more_testings do |t|
          t.change :published_at, :datetime, default: Time.now
        end
      end
    }.new(nil, 2)

    ActiveRecord::Migrator.new(:up, [create_migration, change_migration], @schema_migration, @internal_metadata).migrate

    assert connection.column_exists?(:more_testings, :published_at, precision: 6)
  ensure
    connection.drop_table :more_testings rescue nil
  end

  def test_datetime_sets_precision_6_on_create_table
    migration = Class.new(migration_class) {
      def migrate(x)
        create_table :more_testings do |t|
          t.datetime :published_at
        end
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

    assert connection.column_exists?(:more_testings, :published_at, precision: 6)
  ensure
    connection.drop_table :more_testings rescue nil
  end

  def test_datetime_sets_precision_6_on_change_column
    create_migration = Class.new(migration_class) {
      def migrate(x)
        create_table :more_testings do |t|
          t.date :published_at
        end
      end
    }.new(nil, 0)

    change_migration = Class.new(migration_class) {
      def migrate(x)
        change_column :more_testings, :published_at, :datetime
      end
    }.new(nil, 1)

    ActiveRecord::Migrator.new(:up, [create_migration, change_migration], @schema_migration, @internal_metadata).migrate

    assert connection.column_exists?(:more_testings, :published_at, precision: 6)
  ensure
    connection.drop_table :more_testings rescue nil
  end
end

class BaseCompatibilityTest < ActiveRecord::TestCase
  attr_reader :connection

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @pool = ActiveRecord::Base.connection_pool
    @schema_migration = @pool.schema_migration
    @internal_metadata = @pool.internal_metadata

    @verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  def teardown
    ActiveRecord::Migration.verbose = @verbose_was
    @schema_migration.delete_all_versions rescue nil
  end
end

class CompatibilityTest7_0 < BaseCompatibilityTest
  include DefaultPrecisionSixTestCases
  include NoOptionValidationTestCases

  private
    def migration_class
      ActiveRecord::Migration[7.0]
    end
end

class CompatibilityTest6_1 < BaseCompatibilityTest
  include DefaultPrecisionImplicitTestCases
  include NoOptionValidationTestCases

  private
    def migration_class
      ActiveRecord::Migration[6.1]
    end
end

class CompatibilityTest6_0 < BaseCompatibilityTest
  include DefaultPrecisionImplicitTestCases
  include NoOptionValidationTestCases

  private
    def migration_class
      ActiveRecord::Migration[6.0]
    end
end

class CompatibilityTest5_2 < BaseCompatibilityTest
  include DefaultPrecisionImplicitTestCases
  include NoOptionValidationTestCases

  private
    def migration_class
      ActiveRecord::Migration[5.2]
    end
end

class CompatibilityTest5_1 < BaseCompatibilityTest
  include DefaultPrecisionImplicitTestCases
  include NoOptionValidationTestCases

  private
    def migration_class
      ActiveRecord::Migration[5.1]
    end
end

class CompatibilityTest5_0 < BaseCompatibilityTest
  include DefaultPrecisionImplicitTestCases
  include NoOptionValidationTestCases

  private
    def migration_class
      ActiveRecord::Migration[5.0]
    end
end

class CompatibilityTest4_2 < BaseCompatibilityTest
  include DefaultPrecisionImplicitTestCases
  include NoOptionValidationTestCases

  private
    def migration_class
      ActiveRecord::Migration[4.2]
    end
end

module LegacyPolymorphicReferenceIndexTestCases
  attr_reader :connection

  def setup
    @connection = ActiveRecord::Base.lease_connection
    @pool = ActiveRecord::Base.connection_pool
    @schema_migration = @pool.schema_migration
    @internal_metadata = @pool.internal_metadata
    @verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    connection.create_table :testings, if_not_exists: true
  end

  def teardown
    ActiveRecord::Migration.verbose = @verbose_was
    @schema_migration.delete_all_versions rescue nil
    connection.drop_table :testings rescue nil
  end

  def test_create_table_with_polymorphic_reference_uses_all_column_names_in_index
    migration = Class.new(migration_class) {
      def migrate(x)
        create_table :more_testings do |t|
          t.references :widget, polymorphic: true, index: true
          t.belongs_to :gizmo, polymorphic: true, index: true
        end
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

    assert connection.index_exists?(:more_testings, [:widget_type, :widget_id], name: :index_more_testings_on_widget_type_and_widget_id)
    assert connection.index_exists?(:more_testings, [:gizmo_type, :gizmo_id], name: :index_more_testings_on_gizmo_type_and_gizmo_id)
  ensure
    connection.drop_table :more_testings rescue nil
  end

  def test_change_table_with_polymorphic_reference_uses_all_column_names_in_index
    migration = Class.new(migration_class) {
      def migrate(x)
        change_table :testings do |t|
          t.references :widget, polymorphic: true, index: true
          t.belongs_to :gizmo, polymorphic: true, index: true
        end
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

    assert connection.index_exists?(:testings, [:widget_type, :widget_id], name: :index_testings_on_widget_type_and_widget_id)
    assert connection.index_exists?(:testings, [:gizmo_type, :gizmo_id], name: :index_testings_on_gizmo_type_and_gizmo_id)
  end

  def test_create_join_table_with_polymorphic_reference_uses_all_column_names_in_index
    migration = Class.new(migration_class) {
      def migrate(x)
        create_join_table :more, :testings do |t|
          t.references :widget, polymorphic: true, index: true
          t.belongs_to :gizmo, polymorphic: true, index: true
        end
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

    assert connection.index_exists?(:more_testings, [:widget_type, :widget_id], name: :index_more_testings_on_widget_type_and_widget_id)
    assert connection.index_exists?(:more_testings, [:gizmo_type, :gizmo_id], name: :index_more_testings_on_gizmo_type_and_gizmo_id)
  ensure
    connection.drop_table :more_testings rescue nil
  end

  def test_polymorphic_add_reference_uses_all_column_names_in_index
    migration = Class.new(migration_class) {
      def migrate(x)
        add_reference :testings, :widget, polymorphic: true, index: true
        add_belongs_to :testings, :gizmo, polymorphic: true, index: true
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata).migrate

    assert connection.index_exists?(:testings, [:widget_type, :widget_id], name: :index_testings_on_widget_type_and_widget_id)
    assert connection.index_exists?(:testings, [:gizmo_type, :gizmo_id], name: :index_testings_on_gizmo_type_and_gizmo_id)
  end
end

module LegacyPolymorphicReferenceIndexTest
  class V6_0 < ActiveRecord::TestCase
    include LegacyPolymorphicReferenceIndexTestCases

    self.use_transactional_tests = false

    private
      def migration_class
        ActiveRecord::Migration[6.0]
      end
  end

  class V5_2 < V6_0
    private
      def migration_class
        ActiveRecord::Migration[5.2]
      end
  end

  class V5_1 < V6_0
    private
      def migration_class
        ActiveRecord::Migration[5.1]
      end
  end

  class V5_0 < V6_0
    private
      def migration_class
        ActiveRecord::Migration[5.0]
      end
  end

  class V4_2 < V6_0
    private
      def migration_class
        ActiveRecord::Migration[4.2]
      end
  end
end

module LegacyPrimaryKeyTestCases
  extend ActiveSupport::Concern
  include SchemaDumpingHelper

  class LegacyPrimaryKey < ActiveRecord::Base
  end

  included do
    def setup
      @migration = nil
      @verbose_was = ActiveRecord::Migration.verbose
      ActiveRecord::Migration.verbose = false
    end

    def teardown
      @migration.migrate(:down) if @migration
      ActiveRecord::Migration.verbose = @verbose_was
      ActiveRecord::Base.connection_pool.schema_migration.delete_all_versions rescue nil
      LegacyPrimaryKey.reset_column_information
    end

    def test_legacy_primary_key_should_be_auto_incremented
      @migration = Class.new(migration_class) {
        def change
          create_table :legacy_primary_keys do |t|
            t.references :legacy_ref
          end
        end
      }.new

      @migration.migrate(:up)

      assert_legacy_primary_key

      legacy_ref = LegacyPrimaryKey.columns_hash["legacy_ref_id"]
      assert_not_predicate legacy_ref, :bigint?

      record1 = LegacyPrimaryKey.create!
      assert_not_nil record1.id

      record1.destroy

      record2 = LegacyPrimaryKey.create!
      assert_not_nil record2.id
      assert_operator record2.id, :>, record1.id
    end

    def test_legacy_integer_primary_key_should_not_be_auto_incremented
      skip if current_adapter?(:SQLite3Adapter)

      @migration = Class.new(migration_class) {
        def change
          create_table :legacy_primary_keys, id: :integer do |t|
          end
        end
      }.new

      @migration.migrate(:up)

      assert_raises(ActiveRecord::NotNullViolation) do
        LegacyPrimaryKey.create!
      end

      schema = dump_table_schema "legacy_primary_keys"
      assert_match %r{create_table "legacy_primary_keys", id: :integer, default: nil}, schema
    end

    def test_legacy_primary_key_in_create_table_should_be_integer
      @migration = Class.new(migration_class) {
        def change
          create_table :legacy_primary_keys, id: false do |t|
            t.primary_key :id
          end
        end
      }.new

      @migration.migrate(:up)

      assert_legacy_primary_key
    end

    def test_legacy_primary_key_in_change_table_should_be_integer
      @migration = Class.new(migration_class) {
        def change
          create_table :legacy_primary_keys, id: false do |t|
            t.integer :dummy
          end
          change_table :legacy_primary_keys do |t|
            t.primary_key :id
          end
        end
      }.new

      @migration.migrate(:up)

      assert_legacy_primary_key
    end

    def test_add_column_with_legacy_primary_key_should_be_integer
      @migration = Class.new(migration_class) {
        def change
          create_table :legacy_primary_keys, id: false do |t|
            t.integer :dummy
          end
          add_column :legacy_primary_keys, :id, :primary_key
        end
      }.new

      @migration.migrate(:up)

      assert_legacy_primary_key
    end

    def test_legacy_join_table_foreign_keys_should_be_integer
      @migration = Class.new(migration_class) {
        def change
          create_join_table :apples, :bananas do |t|
          end
        end
      }.new

      @migration.migrate(:up)

      schema = dump_table_schema "apples_bananas"
      assert_match %r{integer "apple_id", null: false}, schema
      assert_match %r{integer "banana_id", null: false}, schema
    end

    def test_legacy_join_table_column_options_should_be_overwritten
      @migration = Class.new(migration_class) {
        def change
          create_join_table :apples, :bananas, column_options: { type: :bigint } do |t|
          end
        end
      }.new

      @migration.migrate(:up)

      schema = dump_table_schema "apples_bananas"
      assert_match %r{bigint "apple_id", null: false}, schema
      assert_match %r{bigint "banana_id", null: false}, schema
    end

    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      def test_legacy_bigint_primary_key_should_be_auto_incremented
        @migration = Class.new(migration_class) {
          def change
            create_table :legacy_primary_keys, id: :bigint
          end
        }.new

        @migration.migrate(:up)

        legacy_pk = LegacyPrimaryKey.columns_hash["id"]
        assert_predicate legacy_pk, :bigint?
        assert_predicate legacy_pk, :auto_increment?

        schema = dump_table_schema "legacy_primary_keys"
        assert_match %r{create_table "legacy_primary_keys", (?!id: :bigint, default: nil)}, schema
      end
    else
      def test_legacy_bigint_primary_key_should_not_be_auto_incremented
        @migration = Class.new(migration_class) {
          def change
            create_table :legacy_primary_keys, id: :bigint do |t|
            end
          end
        }.new

        @migration.migrate(:up)

        assert_raises(ActiveRecord::NotNullViolation) do
          LegacyPrimaryKey.create!
        end

        schema = dump_table_schema "legacy_primary_keys"
        assert_match %r{create_table "legacy_primary_keys", id: :bigint, default: nil}, schema
      end
    end

    private
      def assert_legacy_primary_key
        assert_equal "id", LegacyPrimaryKey.primary_key

        legacy_pk = LegacyPrimaryKey.columns_hash["id"]

        assert_equal :integer, legacy_pk.type
        assert_not_predicate legacy_pk, :bigint?
        assert_not legacy_pk.null

        if current_adapter?(:Mysql2Adapter, :TrilogyAdapter, :PostgreSQLAdapter)
          schema = dump_table_schema "legacy_primary_keys"
          assert_match %r{create_table "legacy_primary_keys", id: :(?:integer|serial), (?!default: nil)}, schema
        end
      end
  end
end

module LegacyPrimaryKeyTest
  class V5_0 < ActiveRecord::TestCase
    include LegacyPrimaryKeyTestCases

    self.use_transactional_tests = false

    private
      def migration_class
        ActiveRecord::Migration[5.0]
      end
  end

  class V4_2 < ActiveRecord::TestCase
    include LegacyPrimaryKeyTestCases

    self.use_transactional_tests = false

    private
      def migration_class
        ActiveRecord::Migration[4.2]
      end
  end
end
