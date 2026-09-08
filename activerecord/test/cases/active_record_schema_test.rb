# frozen_string_literal: true

require "cases/helper"
require "tempfile"

class ActiveRecordSchemaTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  setup do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    @connection = ActiveRecord::Base.lease_connection
    @pool = ActiveRecord::Base.connection_pool
    @schema_migration = @pool.schema_migration
    @schema_migration.delete_all_versions
  end

  teardown do
    @connection.drop_table :fruits rescue nil
    @connection.drop_table :has_timestamps rescue nil
    @connection.drop_table :multiple_indexes rescue nil
    @connection.drop_table :disabled_index rescue nil
    @schema_migration.delete_all_versions
    ActiveRecord::Migration.verbose = @original_verbose
  end

  def test_has_primary_key
    old_primary_key_prefix_type = ActiveRecord::Base.primary_key_prefix_type
    ActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore
    assert_equal "version", @schema_migration.primary_key

    assert_difference "@schema_migration.count", 1 do
      @schema_migration.create_version(12)
    end
  ensure
    ActiveRecord::Base.primary_key_prefix_type = old_primary_key_prefix_type
  end

  def test_schema_migration_create_versions_inserts_string_versions
    @schema_migration.create_versions(["1", "2"])

    assert_equal ["1", "2"], @schema_migration.versions
  end

  def test_schema_without_version_is_the_current_version_schema
    schema_class = ActiveRecord::Schema
    assert schema_class < ActiveRecord::Migration[ActiveRecord::Migration.current_version]
    assert_not schema_class < ActiveRecord::Migration[7.0]
    assert schema_class < ActiveRecord::Schema::Definition
  end

  def test_schema_version_accessor
    schema_class = ActiveRecord::Schema[6.1]
    assert schema_class < ActiveRecord::Migration[6.1]
    assert schema_class < ActiveRecord::Schema::Definition
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
    assert_equal 7, @connection.schema_version
  end

  def test_schema_define_with_table_name_prefix
    old_table_name_prefix = ActiveRecord::Base.table_name_prefix
    ActiveRecord::Base.table_name_prefix = "nep_"
    ActiveRecord::Schema.define(version: 7) do
      create_table :fruits do |t|
        t.column :color, :string
        t.column :fruit_size, :string  # NOTE: "size" is reserved in Oracle
        t.column :texture, :string
        t.column :flavor, :string
      end
    end
    assert_equal 7, @pool.migration_context.current_version
  ensure
    ActiveRecord::Base.table_name_prefix = old_table_name_prefix
    @connection.drop_table :nep_fruits
    @connection.drop_table :nep_schema_migrations
    @schema_migration.create_table
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

  if ActiveRecord::Base.lease_connection.supports_disabling_indexes?
    def test_schema_load_for_index_visibility
      ActiveRecord::Schema.define do
        create_table :disabled_index do |t|
          t.string "foo"
          t.index ["foo"], name: "disabled_foo_index", enabled: false
        end
      end

      indexes = @connection.indexes("disabled_index").find { |index| index.name == "disabled_foo_index" }
      assert_predicate indexes, :disabled?
    end
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_timestamps_with_and_without_zones
      ActiveRecord::Schema.define do
        create_table :has_timestamps do |t|
          t.datetime "default_format"
          t.datetime "without_time_zone"
          t.timestamp "also_without_time_zone"
          t.timestamptz "with_time_zone"
        end
      end

      assert @connection.column_exists?(:has_timestamps, :default_format, :datetime)
      assert @connection.column_exists?(:has_timestamps, :without_time_zone, :datetime)
      assert @connection.column_exists?(:has_timestamps, :also_without_time_zone, :datetime)
      assert @connection.column_exists?(:has_timestamps, :with_time_zone, :timestamptz)
    end
  end

  def test_timestamps_with_implicit_default_on_create_table
    ActiveRecord::Schema.define do
      create_table :has_timestamps do |t|
        t.timestamps
      end
    end

    assert @connection.column_exists?(:has_timestamps, :created_at, precision: 6, null: false)
    assert @connection.column_exists?(:has_timestamps, :updated_at, precision: 6, null: false)
  end

  def test_timestamps_with_implicit_default_on_change_table
    ActiveRecord::Schema.define do
      create_table :has_timestamps

      change_table :has_timestamps do |t|
        t.timestamps default: Time.now
      end
    end

    assert @connection.column_exists?(:has_timestamps, :created_at, precision: 6, null: false)
    assert @connection.column_exists?(:has_timestamps, :updated_at, precision: 6, null: false)
  end

  if ActiveRecord::Base.lease_connection.supports_bulk_alter?
    def test_timestamps_with_implicit_default_on_change_table_with_bulk
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

  def test_timestamps_with_implicit_default_on_add_timestamps
    ActiveRecord::Schema.define do
      create_table :has_timestamps
      add_timestamps :has_timestamps, default: Time.now
    end

    assert @connection.column_exists?(:has_timestamps, :created_at, precision: 6, null: false)
    assert @connection.column_exists?(:has_timestamps, :updated_at, precision: 6, null: false)
  end
end

class ActiveRecordSchemaTest::LoadSchemaMigrationsTest < ActiveRecord::TestCase
  def with_schema_rb(versions_str, nl: "\n", marker: "__END__#{nl}")
    file = Tempfile.new("schema.rb")

    file.write "ActiveRecord::Schema.define {}#{nl}"
    file.write "ActiveRecord::Schema.load_schema_migrations(__FILE__)#{nl}"
    if marker
      file.write marker
      if versions_str
        file.write versions_str
      end
    end
    file.close

    yield file.path
  ensure
    file.unlink
  end

  def assert_versions(expected)
    assert_equal expected, @schema_migration.versions.sort
  end

  setup do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    @pool = ActiveRecord::Base.connection_pool
    @schema_migration = @pool.schema_migration
    @schema_migration.delete_all_versions
  end

  teardown do
    ActiveRecord::Migration.verbose = @original_verbose
  end

  # Regular usage -------------------------------------------------------------

  test "happy path (1)" do
    with_schema_rb("1") do |path|
      ActiveRecord::Schema.load_schema_migrations(path)
      assert_versions ["1"]
    end
  end

  test "happy path (2)" do
    with_schema_rb("1\n") do |path|
      ActiveRecord::Schema.load_schema_migrations(path)
      assert_versions ["1"]
    end
  end

  test "happy path (3)" do
    versions_str = "1\n2\n3\n"
    with_schema_rb(versions_str) do |path|
      ActiveRecord::Schema.load_schema_migrations(path)
      assert_versions ["1", "2", "3"]
    end
  end

  test "it is robust to whitespace" do
    versions_str = "\n\r\n  \n1\t\n2\n\n"

    with_schema_rb(versions_str) do |path|
      ActiveRecord::Schema.load_schema_migrations(path)
      assert_versions ["1", "2"]
    end
  end

  test "supports CRLF line endings" do
    crlf = "\r\n"
    versions_str = "1#{crlf}2#{crlf}"
    with_schema_rb(versions_str, nl: crlf) do |path|
      ActiveRecord::Schema.load_schema_migrations(path)
      assert_versions ["1", "2"]
    end
  end

  test "supports a rogue trailing marker without a newline and without versions" do
    with_schema_rb(nil, marker: "__END__") do |path|
      ActiveRecord::Schema.load_schema_migrations(path)
      assert_versions []
    end
  end

  test "skips versions already in the database" do
    @schema_migration.create_version("1")
    versions_str = "1\n2\n"
    with_schema_rb(versions_str) do |path|
      ActiveRecord::Schema.load_schema_migrations(path)
      assert_versions ["1", "2"]
    end
  end

  # Error conditions ----------------------------------------------------------

  test "rejects duplicate versions" do
    versions_str = "1\n2\n1\n"
    with_schema_rb(versions_str) do |path|
      error = assert_raises(ActiveRecord::ActiveRecordError) do
        ActiveRecord::Schema.load_schema_migrations(path)
      end

      assert_equal 'Duplicate migration version "1" found after __END__', error.message
      assert_versions []
    end
  end

  test "rejects invalid versions" do
    versions_str = "1\ninvalid\n"
    with_schema_rb(versions_str) do |path|
      error = assert_raises(ActiveRecord::ActiveRecordError) do
        ActiveRecord::Schema.load_schema_migrations(path)
      end

      assert_equal 'Invalid migration version "invalid" found after __END__', error.message
      assert_versions []
    end
  end

  test "rejects non ASCII digits" do
    non_ASCII_digit = "\u0967" # Devanagari decimal digit
    assert_match(/\p{Nd}/, non_ASCII_digit) # Nd is a Unicode category for decimal digits.

    versions_str = "1\n#{non_ASCII_digit}\n"
    with_schema_rb(versions_str) do |path|
      error = assert_raises(ActiveRecord::ActiveRecordError) do
        ActiveRecord::Schema.load_schema_migrations(path)
      end

      assert_equal "Invalid migration version #{non_ASCII_digit.inspect} found after __END__", error.message
      assert_versions []
    end
  end

  test "requires an __END__ marker" do
    with_schema_rb(nil, marker: nil) do |path|
      error = assert_raises(ActiveRecord::ActiveRecordError) do
        ActiveRecord::Schema.load_schema_migrations(path)
      end

      assert_equal "No __END__ found in #{path}", error.message
      assert_versions []
    end
  end
end
