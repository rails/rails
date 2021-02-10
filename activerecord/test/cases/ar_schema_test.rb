# frozen_string_literal: true

require "cases/helper"

class ActiveRecordSchemaTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  setup do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    @connection = ActiveRecord::Base.connection
    @schema_migration = @connection.schema_migration
    @schema_migration.drop_table
  end

  teardown do
    @connection.drop_table :fruits rescue nil
    @connection.drop_table :nep_fruits rescue nil
    @connection.drop_table :nep_schema_migrations rescue nil
    @connection.drop_table :has_timestamps rescue nil
    @connection.drop_table :multiple_indexes rescue nil
    @schema_migration.delete_all rescue nil
    ActiveRecord::Migration.verbose = @original_verbose
  end

  def test_has_primary_key
    old_primary_key_prefix_type = ActiveRecord::Base.primary_key_prefix_type
    ActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore
    assert_equal "version", @schema_migration.primary_key

    @schema_migration.create_table
    assert_difference "@schema_migration.count", 1 do
      @schema_migration.create version: 12
    end
  ensure
    @schema_migration.drop_table
    ActiveRecord::Base.primary_key_prefix_type = old_primary_key_prefix_type
  end

  def test_schema_define
    ActiveRecord::Schema.define(version: 7) do
      create_table :fruits do |t|
        t.column :color, :string
        t.column :fruit_size, :string  # NOTE: "size" is reserved in Oracle
        t.column :texture, :string
        t.column :flavor, :string
      end
    end

    assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
    assert_nothing_raised { @connection.select_all "SELECT * FROM schema_migrations" }
    assert_equal 7, @connection.migration_context.current_version
  end

  def test_schema_define_with_table_name_prefix
    old_table_name_prefix = ActiveRecord::Base.table_name_prefix
    ActiveRecord::Base.table_name_prefix = "nep_"
    @schema_migration.reset_table_name
    ActiveRecord::InternalMetadata.reset_table_name
    ActiveRecord::Schema.define(version: 7) do
      create_table :fruits do |t|
        t.column :color, :string
        t.column :fruit_size, :string  # NOTE: "size" is reserved in Oracle
        t.column :texture, :string
        t.column :flavor, :string
      end
    end
    assert_equal 7, @connection.migration_context.current_version
  ensure
    ActiveRecord::Base.table_name_prefix = old_table_name_prefix
    @schema_migration.reset_table_name
    ActiveRecord::InternalMetadata.reset_table_name
  end

  def test_schema_raises_an_error_for_invalid_column_type
    assert_raise NoMethodError do
      ActiveRecord::Schema.define(version: 8) do
        create_table :vegetables do |t|
          t.unknown :color
        end
      end
    end
  end

  def test_schema_subclass
    Class.new(ActiveRecord::Schema).define(version: 9) do
      create_table :fruits
    end
    assert_nothing_raised { @connection.select_all "SELECT * FROM fruits" }
  end

  def test_normalize_version
    assert_equal "118", @schema_migration.normalize_migration_number("0000118")
    assert_equal "002", @schema_migration.normalize_migration_number("2")
    assert_equal "017", @schema_migration.normalize_migration_number("0017")
    assert_equal "20131219224947", @schema_migration.normalize_migration_number("20131219224947")
  end

  def test_schema_load_with_multiple_indexes_for_column_of_different_names
    ActiveRecord::Schema.define do
      create_table :multiple_indexes do |t|
        t.string "foo"
        t.index ["foo"], name: "multiple_indexes_foo_1"
        t.index ["foo"], name: "multiple_indexes_foo_2"
      end
    end

    indexes = @connection.indexes("multiple_indexes")

    assert_equal 2, indexes.length
    assert_equal ["multiple_indexes_foo_1", "multiple_indexes_foo_2"], indexes.collect(&:name).sort
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_timestamps_with_and_without_zones
      ActiveRecord::Schema.define do
        create_table :has_timestamps do |t|
          t.datetime "default_format"
          t.datetime "without_time_zone"
          t.timestamptz "with_time_zone"
        end
      end

      assert @connection.column_exists?(:has_timestamps, :default_format, :datetime)
      assert @connection.column_exists?(:has_timestamps, :without_time_zone, :datetime)
      assert @connection.column_exists?(:has_timestamps, :with_time_zone, :timestamptz)
    end
  end

  def test_timestamps_without_null_set_null_to_false_on_create_table
    ActiveRecord::Schema.define do
      create_table :has_timestamps do |t|
        t.timestamps
      end
    end

    assert @connection.column_exists?(:has_timestamps, :created_at, null: false)
    assert @connection.column_exists?(:has_timestamps, :updated_at, null: false)
  end

  def test_timestamps_without_null_set_null_to_false_on_change_table
    ActiveRecord::Schema.define do
      create_table :has_timestamps

      change_table :has_timestamps do |t|
        t.timestamps default: Time.now
      end
    end

    assert @connection.column_exists?(:has_timestamps, :created_at, null: false)
    assert @connection.column_exists?(:has_timestamps, :updated_at, null: false)
  end

  if ActiveRecord::Base.connection.supports_bulk_alter?
    def test_timestamps_without_null_set_null_to_false_on_change_table_with_bulk
      ActiveRecord::Schema.define do
        create_table :has_timestamps

        change_table :has_timestamps, bulk: true do |t|
          t.timestamps default: Time.now
        end
      end

      assert @connection.column_exists?(:has_timestamps, :created_at, null: false)
      assert @connection.column_exists?(:has_timestamps, :updated_at, null: false)
    end
  end

  def test_timestamps_without_null_set_null_to_false_on_add_timestamps
    ActiveRecord::Schema.define do
      create_table :has_timestamps
      add_timestamps :has_timestamps, default: Time.now
    end

    assert @connection.column_exists?(:has_timestamps, :created_at, null: false)
    assert @connection.column_exists?(:has_timestamps, :updated_at, null: false)
  end

  if supports_datetime_with_precision?
    def test_timestamps_sets_precision_on_create_table
      ActiveRecord::Schema.define do
        create_table :has_timestamps do |t|
          t.timestamps
        end
      end

      assert @connection.column_exists?(:has_timestamps, :created_at, precision: 6, null: false)
      assert @connection.column_exists?(:has_timestamps, :updated_at, precision: 6, null: false)
    end

    def test_timestamps_sets_precision_on_change_table
      ActiveRecord::Schema.define do
        create_table :has_timestamps

        change_table :has_timestamps do |t|
          t.timestamps default: Time.now
        end
      end

      assert @connection.column_exists?(:has_timestamps, :created_at, precision: 6, null: false)
      assert @connection.column_exists?(:has_timestamps, :updated_at, precision: 6, null: false)
    end

    if ActiveRecord::Base.connection.supports_bulk_alter?
      def test_timestamps_sets_precision_on_change_table_with_bulk
        ActiveRecord::Schema.define do
          create_table :has_timestamps

          change_table :has_timestamps, bulk: true do |t|
            t.timestamps default: Time.now
          end
        end

        assert @connection.column_exists?(:has_timestamps, :created_at, precision: 6, null: false)
        assert @connection.column_exists?(:has_timestamps, :updated_at, precision: 6, null: false)
      end
    end

    def test_timestamps_sets_precision_on_add_timestamps
      ActiveRecord::Schema.define do
        create_table :has_timestamps
        add_timestamps :has_timestamps, default: Time.now
      end

      assert @connection.column_exists?(:has_timestamps, :created_at, precision: 6, null: false)
      assert @connection.column_exists?(:has_timestamps, :updated_at, precision: 6, null: false)
    end
  end
end
