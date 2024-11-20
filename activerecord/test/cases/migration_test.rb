# frozen_string_literal: true

require "cases/helper"
require "cases/migration/helper"
require "bigdecimal/util"
require "concurrent/atomic/count_down_latch"

require "models/person"
require "models/topic"
require "models/developer"
require "models/computer"

require MIGRATIONS_ROOT + "/valid/2_we_need_reminders"
require MIGRATIONS_ROOT + "/rename/1_we_need_things"
require MIGRATIONS_ROOT + "/rename/2_rename_things"
require MIGRATIONS_ROOT + "/decimal/1_give_me_big_numbers"

class ValidPeopleHaveLastNames < ActiveRecord::Migration::Current
  def change
    drop_table :people
  end
end

class BigNumber < ActiveRecord::Base
  unless ActiveRecord::TestCase.current_adapter?(:PostgreSQLAdapter, :SQLite3Adapter)
    attribute :value_of_e, :integer
  end
  attribute :my_house_population, :integer
end

class Reminder < ActiveRecord::Base; end

class Thing < ActiveRecord::Base; end

class MigrationTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  fixtures :people

  def setup
    super
    %w(reminders people_reminders prefix_reminders_suffix p_things_s).each do |table|
      Reminder.lease_connection.drop_table(table) rescue nil
    end
    Reminder.reset_column_information
    @verbose_was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false
    @pool = ActiveRecord::Base.connection_pool
    @schema_migration = @pool.schema_migration
    @internal_metadata = @pool.internal_metadata
    ActiveRecord::Base.schema_cache.clear!
  end

  teardown do
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""

    @schema_migration.create_table
    @schema_migration.delete_all_versions

    %w(things awesome_things prefix_things_suffix p_awesome_things_s).each do |table|
      Thing.lease_connection.drop_table(table) rescue nil
    end
    Thing.reset_column_information

    %w(reminders people_reminders prefix_reminders_suffix).each do |table|
      Reminder.lease_connection.drop_table(table) rescue nil
    end
    Reminder.reset_table_name
    Reminder.reset_column_information

    %w(last_name key bio age height wealth birthday favorite_day
       moment_of_truth male administrator funny).each do |column|
      Person.lease_connection.remove_column("people", column) rescue nil
    end
    Person.lease_connection.remove_column("people", "first_name") rescue nil
    Person.lease_connection.remove_column("people", "middle_name") rescue nil
    Person.lease_connection.add_column("people", "first_name", :string)
    Person.reset_column_information

    ActiveRecord::Migration.verbose = @verbose_was
  end

  def test_migration_context_with_default_schema_migration
    migrations_path = MIGRATIONS_ROOT + "/valid"
    migrator = ActiveRecord::MigrationContext.new(migrations_path)
    migrator.up

    assert_equal 3, migrator.current_version
    assert_equal false, migrator.needs_migration?

    migrator.down
    assert_equal 0, migrator.current_version
    assert_equal true, migrator.needs_migration?

    @schema_migration.create_version(3)
    assert_equal true, migrator.needs_migration?
  end

  def test_migration_version_matches_component_version
    assert_equal ActiveRecord::VERSION::STRING.to_f, ActiveRecord::Migration.current_version
  end

  def test_migrator_versions
    migrations_path = MIGRATIONS_ROOT + "/valid"
    migrator = ActiveRecord::MigrationContext.new(migrations_path, @schema_migration, @internal_metadata)

    migrator.up
    assert_equal 3, migrator.current_version
    assert_equal false, migrator.needs_migration?

    migrator.down
    assert_equal 0, migrator.current_version
    assert_equal true, migrator.needs_migration?

    @schema_migration.create_version(3)
    assert_equal true, migrator.needs_migration?
  end

  def test_name_collision_across_dbs
    migrations_path = MIGRATIONS_ROOT + "/valid"
    migrator = ActiveRecord::MigrationContext.new(migrations_path)
    migrator.up

    assert_column Person, :last_name
  end

  def test_migration_detection_without_schema_migration_table
    @schema_migration.drop_table

    migrations_path = MIGRATIONS_ROOT + "/valid"
    migrator = ActiveRecord::MigrationContext.new(migrations_path, @schema_migration, @internal_metadata)

    assert_equal true, migrator.needs_migration?
  ensure
    @schema_migration.create_table
  end

  def test_any_migrations
    migrator = ActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/valid", @schema_migration, @internal_metadata)

    assert_predicate migrator.migrations, :any?

    migrator_empty = ActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/empty", @schema_migration, @internal_metadata)

    assert_not_predicate migrator_empty.migrations, :any?
  end

  def test_migration_version
    migrator = ActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/version_check", @schema_migration, @internal_metadata)
    assert_equal 0, migrator.current_version
    migrator.up(20131219224947)
    assert_equal 20131219224947, migrator.current_version
  end

  def test_create_table_raises_if_already_exists
    connection = Person.lease_connection
    connection.create_table :testings, force: true do |t|
      t.string :foo
    end

    assert_raise(ActiveRecord::StatementInvalid) do
      connection.create_table :testings do |t|
        t.string :foo
      end
    end
  ensure
    connection.drop_table :testings, if_exists: true
  end

  def test_create_table_with_if_not_exists_true
    connection = Person.lease_connection
    connection.create_table :testings, force: true do |t|
      t.string :foo
    end

    assert_nothing_raised do
      connection.create_table :testings, if_not_exists: true do |t|
        t.string :foo
      end
    end
  ensure
    connection.drop_table :testings, if_exists: true
  end

  def test_create_table_raises_for_long_table_names
    connection = Person.lease_connection
    name_limit = connection.table_name_length
    long_name = "a" * (name_limit + 1)
    short_name = "a" * name_limit

    error = assert_raises(ArgumentError) do
      connection.create_table(long_name)
    end
    assert_equal "Table name '#{long_name}' is too long; the limit is #{name_limit} characters", error.message

    connection.create_table(short_name)
    assert connection.table_exists?(short_name)
  ensure
    connection.drop_table short_name, if_exists: true
  end

  def test_create_table_with_force_and_if_not_exists
    connection = Person.lease_connection
    assert_raises(ArgumentError, match: /Options `:force` and `:if_not_exists` cannot be used simultaneously/) do
      connection.create_table(:testings, force: true, if_not_exists: true)
    end
  end

  def test_create_table_with_indexes_and_if_not_exists_true
    connection = Person.lease_connection
    connection.create_table :testings, force: true do |t|
      t.references :people
      t.string :foo
    end

    assert_nothing_raised do
      connection.create_table :testings, if_not_exists: true do |t|
        t.references :people
        t.string :foo
      end
    end
  ensure
    connection.drop_table :testings, if_exists: true
  end

  def test_create_table_with_force_true_does_not_drop_nonexisting_table
    # using a copy as we need the drop_table method to
    # continue to work for the ensure block of the test
    temp_conn = Person.lease_connection.dup

    assert_not_equal temp_conn, Person.lease_connection

    temp_conn.create_table :testings2, force: true do |t|
      t.column :foo, :string
    end
  ensure
    Person.lease_connection.drop_table :testings2, if_exists: true
  end

  def test_remove_column_with_if_not_exists_not_set
    migration_a = Class.new(ActiveRecord::Migration::Current) {
      def version; 100 end
      def migrate(x)
        add_column "people", "last_name", :string
      end
    }.new

    migration_b = Class.new(ActiveRecord::Migration::Current) {
      def version; 101 end
      def migrate(x)
        remove_column "people", "last_name"
      end
    }.new

    migration_c = Class.new(ActiveRecord::Migration::Current) {
      def version; 102 end
      def migrate(x)
        remove_column "people", "last_name"
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration_a], @schema_migration, @internal_metadata, 100).migrate
    assert_column Person, :last_name, "migration_a should have added the last_name column on people"

    ActiveRecord::Migrator.new(:up, [migration_b], @schema_migration, @internal_metadata, 101).migrate
    assert_no_column Person, :last_name, "migration_b should have dropped the last_name column on people"

    migrator = ActiveRecord::Migrator.new(:up, [migration_c], @schema_migration, @internal_metadata, 102)

    if current_adapter?(:SQLite3Adapter)
      assert_nothing_raised do
        migrator.migrate
      end
    else
      error = assert_raises do
        migrator.migrate
      end

      if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        if ActiveRecord::Base.lease_connection.mariadb?
          assert_match(/Can't DROP COLUMN `last_name`; check that it exists/, error.message)
        else
          assert_match(/check that column\/key exists/, error.message)
        end
      elsif current_adapter?(:PostgreSQLAdapter)
        assert_match(/column "last_name" of relation "people" does not exist/, error.message)
      end
    end
  ensure
    Person.reset_column_information
  end

  def test_remove_column_with_if_exists_set
    migration_a = Class.new(ActiveRecord::Migration::Current) {
      def version; 100 end
      def migrate(x)
        add_column "people", "last_name", :string
      end
    }.new

    migration_b = Class.new(ActiveRecord::Migration::Current) {
      def version; 101 end
      def migrate(x)
        remove_column "people", "last_name"
      end
    }.new

    migration_c = Class.new(ActiveRecord::Migration::Current) {
      def version; 102 end
      def migrate(x)
        remove_column "people", "last_name", if_exists: true
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration_a], @schema_migration, @internal_metadata, 100).migrate
    assert_column Person, :last_name, "migration_a should have added the last_name column on people"

    ActiveRecord::Migrator.new(:up, [migration_b], @schema_migration, @internal_metadata, 101).migrate
    assert_no_column Person, :last_name, "migration_b should have dropped the last_name column on people"

    migrator = ActiveRecord::Migrator.new(:up, [migration_c], @schema_migration, @internal_metadata, 102)

    assert_nothing_raised do
      migrator.migrate
    end
  ensure
    Person.reset_column_information
  end

  def test_add_column_with_if_not_exists_not_set
    migration_a = Class.new(ActiveRecord::Migration::Current) {
      def version; 100 end
      def migrate(x)
        add_column "people", "last_name", :string
      end
    }.new

    migration_b = Class.new(ActiveRecord::Migration::Current) {
      def version; 101 end
      def migrate(x)
        add_column "people", "last_name", :string
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration_a], @schema_migration, @internal_metadata, 100).migrate
    assert_column Person, :last_name, "migration_a should have created the last_name column on people"

    assert_raises do
      ActiveRecord::Migrator.new(:up, [migration_b], @schema_migration, @internal_metadata, 101).migrate
    end
  ensure
    Person.reset_column_information
    if Person.column_names.include?("last_name")
      Person.lease_connection.remove_column("people", "last_name")
    end
  end

  def test_add_column_with_if_not_exists_set_to_true
    migration_a = Class.new(ActiveRecord::Migration::Current) {
      def version; 100 end
      def migrate(x)
        add_column "people", "last_name", :string
      end
    }.new

    migration_b = Class.new(ActiveRecord::Migration::Current) {
      def version; 101 end
      def migrate(x)
        add_column "people", "last_name", :string, if_not_exists: true
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration_a], @schema_migration, @internal_metadata, 100).migrate
    assert_column Person, :last_name, "migration_a should have created the last_name column on people"

    assert_nothing_raised do
      ActiveRecord::Migrator.new(:up, [migration_b], @schema_migration, @internal_metadata, 101).migrate
    end
  ensure
    Person.reset_column_information
    if Person.column_names.include?("last_name")
      Person.lease_connection.remove_column("people", "last_name")
    end
  end

  def test_add_column_with_casted_type_if_not_exists_set_to_true
    migration_a = Class.new(ActiveRecord::Migration::Current) {
      def version; 100 end
      def migrate(x)
        type = ActiveRecord::TestCase.current_adapter?(:PostgreSQLAdapter) ? :char : :blob
        add_column "people", "last_name", type
      end
    }.new

    migration_b = Class.new(ActiveRecord::Migration::Current) {
      def version; 101 end
      def migrate(x)
        type = ActiveRecord::TestCase.current_adapter?(:PostgreSQLAdapter) ? :char : :blob
        add_column "people", "last_name", type, if_not_exists: true
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration_a], @schema_migration, @internal_metadata, 100).migrate
    assert_column Person, :last_name, "migration_a should have created the last_name column on people"

    assert_nothing_raised do
      ActiveRecord::Migrator.new(:up, [migration_b], @schema_migration, @internal_metadata, 101).migrate
    end
  ensure
    Person.reset_column_information
    if Person.column_names.include?("last_name")
      Person.lease_connection.remove_column("people", "last_name")
    end
  end

  def test_add_column_with_if_not_exists_set_to_true_does_not_raise_if_type_is_different
    migration_a = Class.new(ActiveRecord::Migration::Current) {
      def version; 100 end
      def migrate(x)
        add_column "people", "last_name", :string
      end
    }.new

    migration_b = Class.new(ActiveRecord::Migration::Current) {
      def version; 101 end
      def migrate(x)
        add_column "people", "last_name", :boolean, if_not_exists: true
      end
    }.new

    ActiveRecord::Migrator.new(:up, [migration_a], @schema_migration, @internal_metadata, 100).migrate
    assert_column Person, :last_name, "migration_a should have created the last_name column on people"

    assert_nothing_raised do
      ActiveRecord::Migrator.new(:up, [migration_b], @schema_migration, @internal_metadata, 101).migrate
    end
  ensure
    Person.reset_column_information
    if Person.column_names.include?("last_name")
      Person.lease_connection.remove_column("people", "last_name")
    end
  end

  def test_migration_instance_has_connection
    migration = Class.new(ActiveRecord::Migration::Current).new
    assert_equal ActiveRecord::Base.lease_connection, migration.connection
  end

  def test_method_missing_delegates_to_connection
    migration = Class.new(ActiveRecord::Migration::Current) {
      def connection
        Class.new {
          def create_table; "hi mom!"; end
        }.new
      end
    }.new

    assert_equal "hi mom!", migration.method_missing(:create_table)
  end

  def test_add_table_with_decimals
    Person.lease_connection.drop_table :big_numbers rescue nil

    assert_not_predicate BigNumber, :table_exists?
    GiveMeBigNumbers.up
    assert_predicate BigNumber, :table_exists?
    BigNumber.reset_column_information

    assert BigNumber.create(
      bank_balance: 1586.43,
      big_bank_balance: BigDecimal("1000234000567.95"),
      world_population: 2**62,
      my_house_population: 3,
      value_of_e: BigDecimal("2.7182818284590452353602875")
    )

    b = BigNumber.first
    assert_not_nil b

    assert_not_nil b.bank_balance
    assert_not_nil b.big_bank_balance
    assert_not_nil b.world_population
    assert_not_nil b.my_house_population
    assert_not_nil b.value_of_e

    assert_kind_of Integer, b.world_population
    assert_equal 2**62, b.world_population
    assert_kind_of Integer, b.my_house_population
    assert_equal 3, b.my_house_population
    assert_kind_of BigDecimal, b.bank_balance
    assert_equal BigDecimal("1586.43"), b.bank_balance
    assert_kind_of BigDecimal, b.big_bank_balance
    assert_equal BigDecimal("1000234000567.95"), b.big_bank_balance

    # This one is fun. The 'value_of_e' field is defined as 'DECIMAL' with
    # precision/scale explicitly left out.  By the SQL standard, numbers
    # assigned to this field should be truncated but that's seldom respected.
    if current_adapter?(:PostgreSQLAdapter)
      # - PostgreSQL changes the SQL spec on columns declared simply as
      # "decimal" to something more useful: instead of being given a scale
      # of 0, they take on the compile-time limit for precision and scale,
      # so the following should succeed unless you have used really wacky
      # compilation options
      assert_kind_of BigDecimal, b.value_of_e
      assert_equal BigDecimal("2.7182818284590452353602875"), b.value_of_e
    elsif current_adapter?(:SQLite3Adapter)
      # - SQLite3 stores a float, in violation of SQL
      assert_kind_of BigDecimal, b.value_of_e
      assert_in_delta BigDecimal("2.71828182845905"), b.value_of_e, 0.00000000000001
    else
      # - SQL standard is an integer
      assert_kind_of Integer, b.value_of_e
      assert_equal 2, b.value_of_e
    end

    GiveMeBigNumbers.down
    assert_raise(ActiveRecord::StatementInvalid) { BigNumber.first }
  end

  def test_filtering_migrations
    assert_no_column Person, :last_name
    assert_not_predicate Reminder, :table_exists?

    name_filter = lambda { |migration| migration.name == "ValidPeopleHaveLastNames" }
    migrator = ActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/valid", @schema_migration, @internal_metadata)
    migrator.up(&name_filter)

    assert_column Person, :last_name
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.first }

    migrator.down(&name_filter)

    assert_no_column Person, :last_name
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.first }
  end

  class MockMigration < ActiveRecord::Migration::Current
    attr_reader :went_up, :went_down
    def initialize
      @went_up   = false
      @went_down = false
    end

    def up
      @went_up = true
      super
    end

    def down
      @went_down = true
      super
    end
  end

  def test_instance_based_migration_up
    migration = MockMigration.new
    assert_not migration.went_up, "have not gone up"
    assert_not migration.went_down, "have not gone down"

    migration.migrate :up
    assert migration.went_up, "have gone up"
    assert_not migration.went_down, "have not gone down"
  end

  def test_instance_based_migration_down
    migration = MockMigration.new
    assert_not migration.went_up, "have not gone up"
    assert_not migration.went_down, "have not gone down"

    migration.migrate :down
    assert_not migration.went_up, "have gone up"
    assert migration.went_down, "have not gone down"
  end

  if ActiveRecord::Base.lease_connection.supports_ddl_transactions?
    def test_migrator_one_up_with_exception_and_rollback
      assert_no_column Person, :last_name

      migration = Class.new(ActiveRecord::Migration::Current) {
        def version; 100 end
        def migrate(x)
          add_column "people", "last_name", :string
          raise "Something broke"
        end
      }.new

      migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 100)

      e = assert_raise(StandardError) { migrator.migrate }

      assert_equal "An error has occurred, this and all later migrations canceled:\n\nSomething broke", e.message

      assert_no_column Person, :last_name,
        "On error, the Migrator should revert schema changes but it did not."
    end

    def test_migrator_one_up_with_exception_and_rollback_using_run
      assert_no_column Person, :last_name

      migration = Class.new(ActiveRecord::Migration::Current) {
        def version; 100 end
        def migrate(x)
          add_column "people", "last_name", :string
          raise "Something broke"
        end
      }.new

      migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 100)

      e = assert_raise(StandardError) { migrator.run }

      assert_equal "An error has occurred, this and all later migrations canceled:\n\nSomething broke", e.message

      assert_no_column Person, :last_name,
        "On error, the Migrator should revert schema changes but it did not."
    end

    def test_migration_without_transaction
      assert_no_column Person, :last_name

      migration = Class.new(ActiveRecord::Migration::Current) {
        disable_ddl_transaction!

        def version; 101 end
        def migrate(x)
          add_column "people", "last_name", :string
          raise "Something broke"
        end
      }.new

      migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 101)
      e = assert_raise(StandardError) { migrator.migrate }
      assert_equal "An error has occurred, all later migrations canceled:\n\nSomething broke", e.message

      assert_column Person, :last_name,
        "without ddl transactions, the Migrator should not rollback on error but it did."
    ensure
      Person.reset_column_information
      if Person.column_names.include?("last_name")
        Person.lease_connection.remove_column("people", "last_name")
      end
    end
  end

  def test_schema_migrations_table_name
    original_schema_migrations_table_name = ActiveRecord::Base.schema_migrations_table_name

    assert_equal "schema_migrations", @schema_migration.table_name
    ActiveRecord::Base.table_name_prefix = "prefix_"
    ActiveRecord::Base.table_name_suffix = "_suffix"
    Reminder.reset_table_name
    assert_equal "prefix_schema_migrations_suffix", @schema_migration.table_name
    ActiveRecord::Base.schema_migrations_table_name = "changed"
    Reminder.reset_table_name
    assert_equal "prefix_changed_suffix", @schema_migration.table_name
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
    Reminder.reset_table_name
    assert_equal "changed", @schema_migration.table_name
  ensure
    ActiveRecord::Base.schema_migrations_table_name = original_schema_migrations_table_name
    Reminder.reset_table_name
  end

  def test_internal_metadata_table_name
    original_internal_metadata_table_name = ActiveRecord::Base.internal_metadata_table_name

    assert_equal "ar_internal_metadata", @internal_metadata.table_name
    ActiveRecord::Base.table_name_prefix = "p_"
    ActiveRecord::Base.table_name_suffix = "_s"
    Reminder.reset_table_name
    assert_equal "p_ar_internal_metadata_s", @internal_metadata.table_name
    ActiveRecord::Base.internal_metadata_table_name = "changed"
    Reminder.reset_table_name
    assert_equal "p_changed_s", @internal_metadata.table_name
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
    Reminder.reset_table_name
    assert_equal "changed", @internal_metadata.table_name
  ensure
    ActiveRecord::Base.internal_metadata_table_name = original_internal_metadata_table_name
    Reminder.reset_table_name
  end

  def test_internal_metadata_stores_environment
    current_env     = env_name(@pool)
    migrations_path = MIGRATIONS_ROOT + "/valid"
    migrator = ActiveRecord::MigrationContext.new(migrations_path, @schema_migration, @internal_metadata)

    migrator.up
    assert_equal current_env, @internal_metadata[:environment]
  end

  def test_internal_metadata_stores_environment_when_migration_fails
    @internal_metadata.delete_all_entries
    current_env = env_name(@pool)

    migration = Class.new(ActiveRecord::Migration::Current) {
      def version; 101 end
      def migrate(x)
        raise "Something broke"
      end
    }.new

    migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 101)
    assert_raise(StandardError) { migrator.migrate }
    assert_equal current_env, @internal_metadata[:environment]
  end

  def test_internal_metadata_stores_environment_when_other_data_exists
    @internal_metadata.delete_all_entries
    @internal_metadata[:foo] = "bar"

    current_env = env_name(@pool)
    migrations_path = MIGRATIONS_ROOT + "/valid"

    migrator = ActiveRecord::MigrationContext.new(migrations_path, @schema_migration, @internal_metadata)
    migrator.up
    assert_equal current_env, @internal_metadata[:environment]
    assert_equal "bar", @internal_metadata[:foo]
  end

  def test_internal_metadata_not_used_when_not_enabled
    @internal_metadata.drop_table
    original_config = @pool.db_config.instance_variable_get(:@configuration_hash)
    modified_config = original_config.dup.merge(use_metadata_table: false)
    @pool.db_config.instance_variable_set(:@configuration_hash, modified_config)

    assert_not @internal_metadata.enabled?
    assert_not @internal_metadata.table_exists?

    migrations_path = MIGRATIONS_ROOT + "/valid"
    migrator = ActiveRecord::MigrationContext.new(migrations_path, @schema_migration, @internal_metadata)
    migrator.up

    assert_not @internal_metadata[:environment]
    assert_not @internal_metadata.table_exists?
  ensure
    @pool.db_config.instance_variable_set(:@configuration_hash, original_config)
    @internal_metadata.create_table
  end

  def test_inserting_a_new_entry_into_internal_metadata
    @internal_metadata[:version] = "foo"
    assert_equal "foo", @internal_metadata[:version]
  ensure
    @internal_metadata.delete_all_entries
  end

  def test_updating_an_existing_entry_into_internal_metadata
    @internal_metadata[:version] = "foo"
    updated_at = @internal_metadata.send(:select_entry, @pool.lease_connection, :version)["updated_at"]
    assert_equal "foo", @internal_metadata[:version]

    # same version doesn't update timestamps
    @internal_metadata[:version] = "foo"
    assert_equal "foo", @internal_metadata[:version]
    assert_equal updated_at, @internal_metadata.send(:select_entry, @pool.lease_connection, :version)["updated_at"]

    # updated version updates timestamps
    @internal_metadata[:version] = "not_foo"
    assert_equal "not_foo", @internal_metadata[:version]
    assert_not_equal updated_at, @internal_metadata.send(:select_entry, @pool.lease_connection, :version)["updated_at"]
  ensure
    @internal_metadata.delete_all_entries
  end

  def test_internal_metadata_create_table_wont_be_affected_by_schema_cache
    @internal_metadata.drop_table
    assert_not_predicate @internal_metadata, :table_exists?

    @pool.with_connection do |connection|
      connection.transaction do
        @internal_metadata.create_table
        assert_predicate @internal_metadata, :table_exists?

        @internal_metadata[:version] = "foo"
        assert_equal "foo", @internal_metadata[:version]
        raise ActiveRecord::Rollback
      end

      connection.transaction do
        @internal_metadata.create_table
        assert_predicate @internal_metadata, :table_exists?

        @internal_metadata[:version] = "bar"
        assert_equal "bar", @internal_metadata[:version]
        raise ActiveRecord::Rollback
      end
    end
  ensure
    @internal_metadata.create_table
  end

  def test_schema_migration_create_table_wont_be_affected_by_schema_cache
    @schema_migration.drop_table
    assert_not_predicate @schema_migration, :table_exists?

    @pool.with_connection do |connection|
      connection.transaction do
        @schema_migration.create_table
        assert_predicate @schema_migration, :table_exists?

        assert_equal "foo", @schema_migration.create_version("foo")
        raise ActiveRecord::Rollback
      end

      connection.transaction do
        @schema_migration.create_table
        assert_predicate @schema_migration, :table_exists?

        assert_equal "bar", @schema_migration.create_version("bar")
        raise ActiveRecord::Rollback
      end
    end
  ensure
    @schema_migration.create_table
  end

  def test_proper_table_name_on_migration
    reminder_class = new_isolated_reminder_class
    migration = ActiveRecord::Migration.new
    assert_equal "table", migration.proper_table_name("table")
    assert_equal "table", migration.proper_table_name(:table)
    assert_equal "reminders", migration.proper_table_name(reminder_class)
    reminder_class.reset_table_name
    assert_equal reminder_class.table_name, migration.proper_table_name(reminder_class)

    # Use the model's own prefix/suffix if a model is given
    ActiveRecord::Base.table_name_prefix = "ARprefix_"
    ActiveRecord::Base.table_name_suffix = "_ARsuffix"
    reminder_class.table_name_prefix = "prefix_"
    reminder_class.table_name_suffix = "_suffix"
    reminder_class.reset_table_name
    assert_equal "prefix_reminders_suffix", migration.proper_table_name(reminder_class)
    reminder_class.table_name_prefix = ""
    reminder_class.table_name_suffix = ""
    reminder_class.reset_table_name

    # Use AR::Base's prefix/suffix if string or symbol is given
    ActiveRecord::Base.table_name_prefix = "prefix_"
    ActiveRecord::Base.table_name_suffix = "_suffix"
    reminder_class.reset_table_name
    assert_equal "prefix_table_suffix", migration.proper_table_name("table", migration.table_name_options)
    assert_equal "prefix_table_suffix", migration.proper_table_name(:table, migration.table_name_options)
  end

  def test_rename_table_with_prefix_and_suffix
    assert_not_predicate Thing, :table_exists?
    ActiveRecord::Base.table_name_prefix = "p_"
    ActiveRecord::Base.table_name_suffix = "_s"
    Thing.reset_table_name
    Thing.reset_sequence_name
    WeNeedThings.up
    assert_predicate Thing, :table_exists?
    Thing.reset_column_information

    assert Thing.create("content" => "hello world")
    assert_equal "hello world", Thing.first.content

    RenameThings.up
    Thing.table_name = "p_awesome_things_s"

    assert_equal "hello world", Thing.first.content
  ensure
    Thing.reset_table_name
    Thing.reset_sequence_name
  end

  def test_add_drop_table_with_prefix_and_suffix
    assert_not_predicate Reminder, :table_exists?
    ActiveRecord::Base.table_name_prefix = "prefix_"
    ActiveRecord::Base.table_name_suffix = "_suffix"
    Reminder.reset_table_name
    Reminder.reset_sequence_name
    WeNeedReminders.up
    assert_predicate Reminder, :table_exists?
    Reminder.reset_column_information
    assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
    assert_equal "hello world", Reminder.first.content

    WeNeedReminders.down
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.first }
  ensure
    Reminder.reset_sequence_name
  end

  def test_create_table_with_binary_column
    assert_nothing_raised {
      Person.lease_connection.create_table :binary_testings do |t|
        t.column "data", :binary, null: false
      end
    }

    columns = Person.lease_connection.columns(:binary_testings)
    data_column = columns.detect { |c| c.name == "data" }

    assert_nil data_column.default
  ensure
    Person.lease_connection.drop_table :binary_testings, if_exists: true
  end

  unless mysql_enforcing_gtid_consistency?
    def test_create_table_with_query
      Person.lease_connection.create_table :table_from_query_testings, as: "SELECT id FROM people WHERE id = 1"

      columns = Person.lease_connection.columns(:table_from_query_testings)
      assert_equal [1], Person.lease_connection.select_values("SELECT * FROM table_from_query_testings")
      assert_equal 1, columns.length
      assert_equal "id", columns.first.name
    ensure
      Person.lease_connection.drop_table :table_from_query_testings rescue nil
    end

    def test_create_table_with_query_from_relation
      Person.lease_connection.create_table :table_from_query_testings, as: Person.select(:id).where(id: 1)

      columns = Person.lease_connection.columns(:table_from_query_testings)
      assert_equal [1], Person.lease_connection.select_values("SELECT * FROM table_from_query_testings")
      assert_equal 1, columns.length
      assert_equal "id", columns.first.name
    ensure
      Person.lease_connection.drop_table :table_from_query_testings rescue nil
    end
  end

  if current_adapter?(:SQLite3Adapter)
    def test_allows_sqlite3_rollback_on_invalid_column_type
      Person.lease_connection.create_table :something, force: true do |t|
        t.column :number, :integer
        t.column :name, :string
        t.column :foo, :bar
      end
      assert Person.lease_connection.column_exists?(:something, :foo)
      assert_nothing_raised { Person.lease_connection.remove_column :something, :foo, :bar }
      assert_not Person.lease_connection.column_exists?(:something, :foo)
      assert Person.lease_connection.column_exists?(:something, :name)
      assert Person.lease_connection.column_exists?(:something, :number)
    ensure
      Person.lease_connection.drop_table :something, if_exists: true
    end
  end

  def test_decimal_scale_without_precision_should_raise
    e = assert_raise(ArgumentError) do
      Person.lease_connection.create_table :test_decimal_scales, force: true do |t|
        t.decimal :scaleonly, scale: 10
      end
    end

    assert_equal "Error adding decimal column: precision cannot be empty if scale is specified", e.message
  ensure
    Person.lease_connection.drop_table :test_decimal_scales, if_exists: true
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter, :PostgreSQLAdapter)
    def test_out_of_range_integer_limit_should_raise
      e = assert_raise(ArgumentError) do
        Person.lease_connection.create_table :test_integer_limits, force: true do |t|
          t.column :bigone, :integer, limit: 10
        end
      end

      assert_includes e.message, "No integer type has byte size 10"
    ensure
      Person.lease_connection.drop_table :test_integer_limits, if_exists: true
    end

    def test_out_of_range_text_limit_should_raise
      e = assert_raise(ArgumentError) do
        Person.lease_connection.create_table :test_text_limits, force: true do |t|
          t.text :bigtext, limit: 0xfffffffff
        end
      end

      assert_includes e.message, "No text type has byte size #{0xfffffffff}"
    ensure
      Person.lease_connection.drop_table :test_text_limits, if_exists: true
    end

    def test_out_of_range_binary_limit_should_raise
      e = assert_raise(ArgumentError) do
        Person.lease_connection.create_table :test_binary_limits, force: true do |t|
          t.binary :bigbinary, limit: 0xfffffffff
        end
      end

      assert_includes e.message, "No binary type has byte size #{0xfffffffff}"
    ensure
      Person.lease_connection.drop_table :test_binary_limits, if_exists: true
    end
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_invalid_text_size_should_raise
      e = assert_raise(ArgumentError) do
        Person.lease_connection.create_table :test_text_sizes, force: true do |t|
          t.text :bigtext, size: 0xfffffffff
        end
      end

      assert_equal "#{0xfffffffff} is invalid :size value. Only :tiny, :medium, and :long are allowed.", e.message
    ensure
      Person.lease_connection.drop_table :test_text_sizes, if_exists: true
    end
  end

  if ActiveRecord::Base.lease_connection.supports_advisory_locks?
    def test_migrator_generates_valid_lock_id
      migration = Class.new(ActiveRecord::Migration::Current).new
      migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 100)

      lock_id = migrator.send(:generate_migrator_advisory_lock_id)

      assert ActiveRecord::Base.lease_connection.get_advisory_lock(lock_id),
        "the Migrator should have generated a valid lock id, but it didn't"
      assert ActiveRecord::Base.lease_connection.release_advisory_lock(lock_id),
        "the Migrator should have generated a valid lock id, but it didn't"
    end

    def test_generate_migrator_advisory_lock_id
      # It is important we are consistent with how we generate this so that
      # exclusive locking works across migrator versions
      migration = Class.new(ActiveRecord::Migration::Current).new
      migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 100)

      lock_id = migrator.send(:generate_migrator_advisory_lock_id)

      current_database = ActiveRecord::Base.lease_connection.current_database
      salt = ActiveRecord::Migrator::MIGRATOR_SALT
      expected_id = Zlib.crc32(current_database) * salt

      assert lock_id == expected_id, "expected lock id generated by the migrator to be #{expected_id}, but it was #{lock_id} instead"
      assert lock_id.bit_length <= 63, "lock id must be a signed integer of max 63 bits magnitude"
    end

    def test_migrator_one_up_with_unavailable_lock
      assert_no_column Person, :last_name

      migration = Class.new(ActiveRecord::Migration::Current) {
        def version; 100 end
        def migrate(x)
          add_column "people", "last_name", :string
        end
      }.new

      migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 100)
      lock_id = migrator.send(:generate_migrator_advisory_lock_id)

      with_another_process_holding_lock(lock_id) do
        assert_raise(ActiveRecord::ConcurrentMigrationError) { migrator.migrate }
      end

      assert_no_column Person, :last_name,
        "without an advisory lock, the Migrator should not make any changes, but it did."
    end

    def test_migrator_one_up_with_unavailable_lock_using_run
      assert_no_column Person, :last_name

      migration = Class.new(ActiveRecord::Migration::Current) {
        def version; 100 end
        def migrate(x)
          add_column "people", "last_name", :string
        end
      }.new

      migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 100)
      lock_id = migrator.send(:generate_migrator_advisory_lock_id)

      with_another_process_holding_lock(lock_id) do
        assert_raise(ActiveRecord::ConcurrentMigrationError) { migrator.run }
      end

      assert_no_column Person, :last_name,
        "without an advisory lock, the Migrator should not make any changes, but it did."
    end

    if current_adapter?(:PostgreSQLAdapter)
      def test_with_advisory_lock_closes_connection
        migration = Class.new(ActiveRecord::Migration::Current) {
          def version; 100 end
          def migrate(x)
          end
        }.new

        migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 100)
        lock_id = migrator.send(:generate_migrator_advisory_lock_id)

        query = <<~SQL
        SELECT query
        FROM pg_stat_activity
        WHERE datname = '#{ActiveRecord::Base.connection_db_config.database}'
        AND state = 'idle'
        AND query LIKE '%#{lock_id}%'
        SQL

        assert_no_changes -> { ActiveRecord::Base.lease_connection.exec_query(query).rows.flatten } do
          migrator.migrate
        end
      end
    end

    def test_with_advisory_lock_raises_the_right_error_when_it_fails_to_release_lock
      migration = Class.new(ActiveRecord::Migration::Current).new
      migrator = ActiveRecord::Migrator.new(:up, [migration], @schema_migration, @internal_metadata, 100)
      lock_id = migrator.send(:generate_migrator_advisory_lock_id)

      e = assert_raises(ActiveRecord::ConcurrentMigrationError) do
        silence_stream($stderr) do
          migrator.send(:with_advisory_lock) do
            ActiveRecord::Base.lease_connection.release_advisory_lock(lock_id)
          end
        end
      end

      assert_match(
        /#{ActiveRecord::ConcurrentMigrationError::RELEASE_LOCK_FAILED_MESSAGE}/,
        e.message
      )
    end
  end

  private
    # This is needed to isolate class_attribute assignments like `table_name_prefix`
    # for each test case.
    def new_isolated_reminder_class
      Class.new(Reminder) {
        def self.name; "Reminder"; end
        def self.base_class; self; end
      }
    end

    def with_another_process_holding_lock(lock_id)
      thread_lock = Concurrent::CountDownLatch.new
      test_terminated = Concurrent::CountDownLatch.new

      other_process = Thread.new do
        conn = ActiveRecord::Base.connection_pool.checkout
        conn.get_advisory_lock(lock_id)
        thread_lock.count_down
        test_terminated.wait # hold the lock open until we tested everything
      ensure
        conn.release_advisory_lock(lock_id)
        ActiveRecord::Base.connection_pool.checkin(conn)
      end

      thread_lock.wait # wait until the 'other process' has the lock

      yield

      test_terminated.count_down
      other_process.join
    end

    def env_name(pool)
      pool.db_config.env_name
    end
end

class ReservedWordsMigrationTest < ActiveRecord::TestCase
  def test_drop_index_from_table_named_values
    connection = Person.lease_connection
    connection.create_table :values, force: true do |t|
      t.integer :value
    end

    assert_nothing_raised do
      connection.add_index :values, :value
      connection.remove_index :values, :value
    end
  ensure
    connection.drop_table :values rescue nil
  end
end

class ExplicitlyNamedIndexMigrationTest < ActiveRecord::TestCase
  def test_drop_index_by_name
    connection = Person.lease_connection
    connection.create_table :values, force: true do |t|
      t.integer :value
    end

    assert_nothing_raised do
      connection.add_index :values, :value, name: "a_different_name"
      connection.remove_index :values, :value, name: "a_different_name"
    end
  ensure
    connection.drop_table :values rescue nil
  end
end

class IndexForTableWithSchemaMigrationTest < ActiveRecord::TestCase
  if current_adapter?(:PostgreSQLAdapter)
    def test_add_and_remove_index
      connection = Person.lease_connection
      connection.create_schema("my_schema")
      connection.create_table("my_schema.values", force: true) do |t|
        t.integer :value
      end

      connection.add_index("my_schema.values", :value)
      assert connection.index_exists?("my_schema.values", :value)

      connection.remove_index("my_schema.values", :value)
      assert_not connection.index_exists?("my_schema.values", :value)
    ensure
      connection.drop_schema("my_schema")
    end
  end
end

if ActiveRecord::Base.lease_connection.supports_bulk_alter?
  class BulkAlterTableMigrationsTest < ActiveRecord::TestCase
    def setup
      @connection = Person.lease_connection
      @connection.create_table(:delete_me, force: true) { |t| }
      Person.reset_column_information
      Person.reset_sequence_name
    end

    teardown do
      Person.lease_connection.drop_table(:delete_me) rescue nil
    end

    def test_adding_multiple_columns
      classname = ActiveRecord::Base.lease_connection.class.name[/[^:]*$/]
      expected_query_count = {
        "Mysql2Adapter"     => 1,
        "TrilogyAdapter"    => 1,
        "PostgreSQLAdapter" => 2, # one for bulk change, one for comment
      }.fetch(classname) {
        raise "need an expected query count for #{classname}"
      }

      assert_queries_count(expected_query_count) do
        with_bulk_change_table do |t|
          t.column :name, :string
          t.string :qualification, :experience
          t.integer :age, default: 0
          t.date :birthdate, comment: "This is a comment"
          t.timestamps null: true
        end
      end

      assert_equal 8, columns.size
      [:name, :qualification, :experience].each { |s| assert_equal :string, column(s).type }
      assert_equal "0", column(:age).default
      assert_equal "This is a comment", column(:birthdate).comment
    end

    def test_rename_columns
      with_bulk_change_table do |t|
        t.string :qualification
      end

      assert column(:qualification)

      with_bulk_change_table do |t|
        t.rename :qualification, :experience
        t.string :qualification_experience
      end

      assert_not column(:qualification)
      assert column(:experience)
      assert column(:qualification_experience)
    end

    def test_removing_columns
      with_bulk_change_table do |t|
        t.string :qualification, :experience
      end

      [:qualification, :experience].each { |c| assert column(c) }

      assert_queries_count(1) do
        with_bulk_change_table do |t|
          t.remove :qualification, :experience
          t.string :qualification_experience
        end
      end

      [:qualification, :experience].each { |c| assert_not column(c) }
      assert column(:qualification_experience)
    end

    def test_adding_timestamps
      with_bulk_change_table do |t|
        t.string :title
      end

      assert column(:title)

      assert_queries_count(1) do
        with_bulk_change_table do |t|
          t.timestamps
          t.remove :title
        end
      end

      [:created_at, :updated_at].each { |c| assert column(c) }
      assert_not column(:title)
    end

    def test_removing_timestamps
      with_bulk_change_table do |t|
        t.timestamps
      end

      [:created_at, :updated_at].each { |c| assert column(c) }

      assert_queries_count(1) do
        with_bulk_change_table do |t|
          t.remove_timestamps
          t.string :title
        end
      end

      [:created_at, :updated_at].each { |c| assert_not column(c) }
      assert column(:title)
    end

    def test_adding_indexes
      with_bulk_change_table do |t|
        t.string :username
        t.string :name
        t.integer :age
      end

      classname = ActiveRecord::Base.lease_connection.class.name[/[^:]*$/]
      expected_query_count = {
        "Mysql2Adapter"     => 1, # mysql2 supports creating two indexes using one statement
        "TrilogyAdapter"    => 1, # trilogy supports creating two indexes using one statement
        "PostgreSQLAdapter" => 3,
      }.fetch(classname) {
        raise "need an expected query count for #{classname}"
      }

      assert_queries_count(expected_query_count) do
        with_bulk_change_table do |t|
          t.index :username, unique: true, name: :awesome_username_index
          t.index [:name, :age], comment: "This is a comment"
        end
      end

      assert_equal 2, indexes.size

      name_age_index = index(:index_delete_me_on_name_and_age)
      assert_equal ["name", "age"].sort, name_age_index.columns.sort
      assert_equal "This is a comment", name_age_index.comment
      assert_not name_age_index.unique

      assert index(:awesome_username_index).unique
    end

    def test_removing_index
      with_bulk_change_table do |t|
        t.string :name
        t.index :name
      end

      assert index(:index_delete_me_on_name)

      classname = ActiveRecord::Base.lease_connection.class.name[/[^:]*$/]
      expected_query_count = {
        "Mysql2Adapter"     => 1, # mysql2 supports dropping and creating two indexes using one statement
        "TrilogyAdapter"    => 1, # trilogy supports dropping and creating two indexes using one statement
        "PostgreSQLAdapter" => 2,
      }.fetch(classname) {
        raise "need an expected query count for #{classname}"
      }

      assert_queries_count(expected_query_count) do
        with_bulk_change_table do |t|
          t.remove_index :name
          t.index :name, name: :new_name_index, unique: true
        end
      end

      assert_not index(:index_delete_me_on_name)

      new_name_index = index(:new_name_index)
      assert new_name_index.unique
    end

    def test_changing_columns
      with_bulk_change_table do |t|
        t.string :name
        t.date :birthdate
      end

      assert_not column(:name).default
      assert_equal :date, column(:birthdate).type

      classname = ActiveRecord::Base.lease_connection.class.name[/[^:]*$/]
      expected_query_count = {
        "Mysql2Adapter"     => 3, # one query for columns, one query for primary key, one query to do the bulk change
        "TrilogyAdapter"    => 3, # one query for columns, one query for primary key, one query to do the bulk change
        "PostgreSQLAdapter" => 3, # one query for columns, one for bulk change, one for comment
      }.fetch(classname) {
        raise "need an expected query count for #{classname}"
      }

      assert_queries_count(expected_query_count, include_schema: true) do
        with_bulk_change_table do |t|
          t.change :name, :string, default: "NONAME"
          t.change :birthdate, :datetime, comment: "This is a comment"
        end
      end

      assert_equal "NONAME", column(:name).default
      assert_equal :datetime, column(:birthdate).type
      assert_equal "This is a comment", column(:birthdate).comment
    end

    def test_changing_column_null_with_default
      with_bulk_change_table do |t|
        t.string :name
        t.integer :age
        t.date :birthdate
      end

      assert_not column(:name).default
      assert_equal :date, column(:birthdate).type

      classname = ActiveRecord::Base.lease_connection.class.name[/[^:]*$/]
      expected_query_count = {
        "Mysql2Adapter"     => 7, # four queries to retrieve schema info, one for bulk change, one for UPDATE, one for NOT NULL
        "TrilogyAdapter"    => 7, # four queries to retrieve schema info, one for bulk change, one for UPDATE, one for NOT NULL
        "PostgreSQLAdapter" => 5, # two queries for columns, one for bulk change, one for UPDATE, one for NOT NULL
      }.fetch(classname) {
        raise "need an expected query count for #{classname}"
      }

      assert_queries_count(expected_query_count, include_schema: true) do
        with_bulk_change_table do |t|
          t.change :name, :string, default: "NONAME"
          t.change :birthdate, :datetime
          t.change_null :age, false, 0
        end
      end

      assert_equal "NONAME", column(:name).default
      assert_equal :datetime, column(:birthdate).type
      assert_equal false, column(:age).null
    end

    if supports_text_column_with_default?
      def test_default_functions_on_columns
        with_bulk_change_table do |t|
          if current_adapter?(:PostgreSQLAdapter)
            t.string :name, default: -> { "gen_random_uuid()" }
          else
            t.string :name, default: -> { "UUID()" }
          end
        end

        assert_nil column(:name).default

        if current_adapter?(:PostgreSQLAdapter)
          assert_equal "gen_random_uuid()", column(:name).default_function
          Person.lease_connection.execute("INSERT INTO delete_me DEFAULT VALUES")
        else
          assert_equal "uuid()", column(:name).default_function
          Person.lease_connection.execute("INSERT INTO delete_me () VALUES ()")
        end

        person_data = Person.lease_connection.select_one("SELECT * FROM delete_me ORDER BY id DESC")
        assert_match(/\A(.+)-(.+)-(.+)-(.+)\Z/, person_data.fetch("name"))
      end
    end

    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      def test_updating_auto_increment
        with_bulk_change_table do |t|
          t.change :id, :bigint, auto_increment: true
        end

        assert_predicate column(:id), :auto_increment?

        with_bulk_change_table do |t|
          t.change :id, :bigint, auto_increment: false
        end
        assert_not column(:id).auto_increment?
      end
    end

    def test_changing_index
      with_bulk_change_table do |t|
        t.string :username
        t.index :username, name: :username_index
      end

      assert index(:username_index)
      assert_not index(:username_index).unique

      classname = ActiveRecord::Base.lease_connection.class.name[/[^:]*$/]
      expected_query_count = {
        "Mysql2Adapter"     => 1, # mysql2 supports dropping and creating two indexes using one statement
        "TrilogyAdapter"    => 1, # trilogy supports dropping and creating two indexes using one statement
        "PostgreSQLAdapter" => 2,
      }.fetch(classname) {
        raise "need an expected query count for #{classname}"
      }

      assert_queries_count(expected_query_count) do
        with_bulk_change_table do |t|
          t.remove_index name: :username_index
          t.index :username, name: :username_index, unique: true
        end
      end

      assert index(:username_index)
      assert index(:username_index).unique
    end

    private
      def with_bulk_change_table(&block)
        # Reset columns/indexes cache as we're changing the table
        @columns = @indexes = nil

        Person.lease_connection.change_table(:delete_me, bulk: true, &block)
      end

      def column(name)
        columns.detect { |c| c.name == name.to_s }
      end

      def columns
        @columns ||= Person.lease_connection.columns("delete_me")
      end

      def index(name)
        indexes.detect { |i| i.name == name.to_s }
      end

      def indexes
        @indexes ||= Person.lease_connection.indexes("delete_me")
      end
  end # AlterTableMigrationsTest

  class RevertBulkAlterTableMigrationsTest < ActiveRecord::TestCase
    self.use_transactional_tests = false

    def setup
      @connection = Person.lease_connection
      Person.reset_column_information
      Person.reset_sequence_name
    end

    teardown do
      @connection.remove_columns(:people, :column1, :column2) rescue nil
    end

    def test_bulk_revert
      @connection.add_column(:people, :column1, :string)
      @connection.add_column(:people, :column2, :string)
      assert_column Person, :column1
      assert_column Person, :column2

      migration = Class.new(ActiveRecord::Migration::Current) {
        disable_ddl_transaction!

        def write(text = ""); end

        def change
          change_table :people, bulk: true do |t|
            t.column :column1, :string
            t.column :column2, :string
          end
        end
      }.new

      assert_queries_count(1) do
        migration.migrate(:down)
      end

      assert_no_column Person, :column1
      assert_no_column Person, :column2
    end
  end
end

class CopyMigrationsTest < ActiveRecord::TestCase
  include ActiveSupport::Testing::Stream

  def setup
  end

  def clear
    ActiveRecord.timestamped_migrations = true
    to_delete = Dir[@migrations_path + "/*.rb"] - @existing_migrations
    File.delete(*to_delete)
  end

  def test_copying_migrations_without_timestamps
    ActiveRecord.timestamped_migrations = false
    @migrations_path = MIGRATIONS_ROOT + "/valid"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    copied = ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/to_copy")
    assert File.exist?(@migrations_path + "/4_people_have_hobbies.bukkits.rb")
    assert File.exist?(@migrations_path + "/5_people_have_descriptions.bukkits.rb")
    assert_equal [@migrations_path + "/4_people_have_hobbies.bukkits.rb", @migrations_path + "/5_people_have_descriptions.bukkits.rb"], copied.map(&:filename)

    expected = "# This migration comes from bukkits (originally 1)"
    assert_equal expected, IO.readlines(@migrations_path + "/4_people_have_hobbies.bukkits.rb")[2].chomp

    files_count = Dir[@migrations_path + "/*.rb"].length
    copied = ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/to_copy")
    assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
    assert_empty copied
  ensure
    clear
  end

  def test_copying_migrations_without_timestamps_from_2_sources
    ActiveRecord.timestamped_migrations = false
    @migrations_path = MIGRATIONS_ROOT + "/valid"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    sources = {}
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy"
    sources[:omg] = MIGRATIONS_ROOT + "/to_copy2"
    ActiveRecord::Migration.copy(@migrations_path, sources)
    assert File.exist?(@migrations_path + "/4_people_have_hobbies.bukkits.rb")
    assert File.exist?(@migrations_path + "/5_people_have_descriptions.bukkits.rb")
    assert File.exist?(@migrations_path + "/6_create_articles.omg.rb")
    assert File.exist?(@migrations_path + "/7_create_comments.omg.rb")

    files_count = Dir[@migrations_path + "/*.rb"].length
    ActiveRecord::Migration.copy(@migrations_path, sources)
    assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
  ensure
    clear
  end

  def test_copying_migrations_with_timestamps
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/to_copy_with_timestamps")
      assert File.exist?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      expected = [@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb",
                  @migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb"]
      assert_equal expected, copied.map(&:filename)

      files_count = Dir[@migrations_path + "/*.rb"].length
      copied = ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/to_copy_with_timestamps")
      assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
      assert_empty copied
    end
  ensure
    clear
  end

  def test_copying_migrations_with_timestamps_from_2_sources
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    sources = {}
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy_with_timestamps"
    sources[:omg]     = MIGRATIONS_ROOT + "/to_copy_with_timestamps2"

    travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, sources)
      assert File.exist?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101012_create_articles.omg.rb")
      assert File.exist?(@migrations_path + "/20100726101013_create_comments.omg.rb")
      assert_equal 4, copied.length

      files_count = Dir[@migrations_path + "/*.rb"].length
      ActiveRecord::Migration.copy(@migrations_path, sources)
      assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
    end
  ensure
    clear
  end

  def test_copying_migrations_with_timestamps_to_destination_with_timestamps_in_future
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    travel_to(Time.utc(2010, 2, 20, 10, 10, 10)) do
      ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/to_copy_with_timestamps")
      assert File.exist?(@migrations_path + "/20100301010102_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100301010103_people_have_descriptions.bukkits.rb")

      files_count = Dir[@migrations_path + "/*.rb"].length
      copied = ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/to_copy_with_timestamps")
      assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
      assert_empty copied
    end
  ensure
    clear
  end

  def test_copying_migrations_preserving_magic_comments
    ActiveRecord.timestamped_migrations = false
    @migrations_path = MIGRATIONS_ROOT + "/valid"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    copied = ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/magic")
    assert File.exist?(@migrations_path + "/4_currencies_have_symbols.bukkits.rb")
    assert_equal [@migrations_path + "/4_currencies_have_symbols.bukkits.rb"], copied.map(&:filename)

    expected = "# frozen_string_literal: true\n# coding: ISO-8859-15\n\n# This migration comes from bukkits (originally 1)"
    assert_equal expected, IO.readlines(@migrations_path + "/4_currencies_have_symbols.bukkits.rb")[0..3].join.chomp

    files_count = Dir[@migrations_path + "/*.rb"].length
    copied = ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/magic")
    assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
    assert_empty copied
  ensure
    clear
  end

  def test_skipping_migrations
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    sources = {}
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy_with_timestamps"
    sources[:omg]     = MIGRATIONS_ROOT + "/to_copy_with_name_collision"

    skipped = []
    on_skip = Proc.new { |name, migration| skipped << "#{name} #{migration.name}" }
    copied = ActiveRecord::Migration.copy(@migrations_path, sources, on_skip: on_skip)
    assert_equal 2, copied.length

    assert_equal 1, skipped.length
    assert_equal ["omg PeopleHaveHobbies"], skipped
  ensure
    clear
  end

  def test_skip_is_not_called_if_migrations_are_from_the_same_plugin
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    sources = {}
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy_with_timestamps"

    skipped = []
    on_skip = Proc.new { |name, migration| skipped << "#{name} #{migration.name}" }
    copied = ActiveRecord::Migration.copy(@migrations_path, sources, on_skip: on_skip)
    ActiveRecord::Migration.copy(@migrations_path, sources, on_skip: on_skip)

    assert_equal 2, copied.length
    assert_equal 0, skipped.length
  ensure
    clear
  end

  def test_copying_migrations_to_non_existing_directory
    @migrations_path = MIGRATIONS_ROOT + "/non_existing"
    @existing_migrations = []

    travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/to_copy_with_timestamps")
      assert File.exist?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      assert_equal 2, copied.length
    end
  ensure
    clear
    Dir.delete(@migrations_path)
  end

  def test_copying_migrations_to_empty_directory
    @migrations_path = MIGRATIONS_ROOT + "/empty"
    @existing_migrations = []

    travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, bukkits: MIGRATIONS_ROOT + "/to_copy_with_timestamps")
      assert File.exist?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      assert_equal 2, copied.length
    end
  ensure
    clear
  end

  def test_check_pending_with_stdlib_logger
    old, ActiveRecord::Base.logger = ActiveRecord::Base.logger, ::Logger.new($stdout)
    quietly do
      assert_nothing_raised { ActiveRecord::Migration::CheckPending.new(Proc.new { }).call({}) }
    end
  ensure
    ActiveRecord::Base.logger = old
  end

  def test_unknown_migration_version_should_raise_an_argument_error
    assert_raise(ArgumentError) { ActiveRecord::Migration[1.0] }
  end

  class MigrationValidationTest < ActiveRecord::TestCase
    def setup
      @verbose_was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false
      @schema_migration = ActiveRecord::Base.connection_pool.schema_migration
      @internal_metadata = ActiveRecord::Base.connection_pool.internal_metadata
      @active_record_validate_timestamps_was = ActiveRecord.validate_migration_timestamps
      ActiveRecord.validate_migration_timestamps = true
      ActiveRecord::Base.schema_cache.clear!

      @migrations_path = MIGRATIONS_ROOT + "/temp"
      @migrator = ActiveRecord::MigrationContext.new(@migrations_path, @schema_migration, @internal_metadata)
    end

    def teardown
      @schema_migration.create_table
      @schema_migration.delete_all_versions
      ActiveRecord.validate_migration_timestamps = @active_record_validate_timestamps_was
      ActiveRecord::Migration.verbose = @verbose_was
    end

    def test_migration_raises_if_timestamp_greater_than_14_digits
      with_temp_migration_files(["201801010101010000_test_migration.rb"]) do
        error = assert_raises(ActiveRecord::InvalidMigrationTimestampError) do
          @migrator.up(201801010101010000)
        end
        assert_match(/Invalid timestamp 201801010101010000 for migration file: test_migration/, error.message)
      end
    end

    def test_migration_raises_if_timestamp_is_future_date
      timestamp = (Time.now.utc + 1.month).strftime("%Y%m%d%H%M%S").to_i
      with_temp_migration_files(["#{timestamp}_test_migration.rb"]) do
        error = assert_raises(ActiveRecord::InvalidMigrationTimestampError) do
          @migrator.up(timestamp)
        end
        assert_match(/Invalid timestamp #{timestamp} for migration file: test_migration/, error.message)
      end
    end

    def test_migration_succeeds_if_timestamp_is_less_than_one_day_in_the_future
      timestamp = (Time.now.utc + 1.minute).strftime("%Y%m%d%H%M%S").to_i
      with_temp_migration_files(["#{timestamp}_test_migration.rb"]) do
        @migrator.up(timestamp)
        assert_equal timestamp, @migrator.current_version
      end
    end

    def test_migration_succeeds_despite_future_timestamp_if_validate_timestamps_is_false
      validate_migration_timestamps_was = ActiveRecord.validate_migration_timestamps
      ActiveRecord.validate_migration_timestamps = false

      timestamp = (Time.now.utc + 1.month).strftime("%Y%m%d%H%M%S").to_i
      with_temp_migration_files(["#{timestamp}_test_migration.rb"]) do
        @migrator.up(timestamp)
        assert_equal timestamp, @migrator.current_version
      end
    ensure
      ActiveRecord.validate_migration_timestamps = validate_migration_timestamps_was
    end

    def test_migration_succeeds_despite_future_timestamp_if_timestamped_migrations_is_false
      timestamped_migrations_was = ActiveRecord.timestamped_migrations
      ActiveRecord.timestamped_migrations = false

      timestamp = (Time.now.utc + 1.month).strftime("%Y%m%d%H%M%S").to_i
      with_temp_migration_files(["#{timestamp}_test_migration.rb"]) do
        @migrator.up(timestamp)
        assert_equal timestamp, @migrator.current_version
      end
    ensure
      ActiveRecord.timestamped_migrations = timestamped_migrations_was
    end

    def test_copied_migrations_at_timestamp_boundary_are_valid
      migrations_path_source = MIGRATIONS_ROOT + "/temp_source"
      migrations_path_dest = MIGRATIONS_ROOT + "/temp_dest"
      migrations = ["20180101010101_test_migration.rb", "20180101010102_test_migration_two.rb", "20180101010103_test_migration_three.rb"]

      with_temp_migration_files(migrations, migrations_path_source) do
        travel_to(Time.utc(2023, 12, 1, 10, 10, 59)) do
          ActiveRecord::Migration.copy(migrations_path_dest, temp: migrations_path_source)

          assert File.exist?(migrations_path_dest + "/20231201101059_test_migration.temp.rb")
          assert File.exist?(migrations_path_dest + "/20231201101060_test_migration_two.temp.rb")
          assert File.exist?(migrations_path_dest + "/20231201101061_test_migration_three.temp.rb")

          migrator = ActiveRecord::MigrationContext.new(migrations_path_dest, @schema_migration, @internal_metadata)
          migrator.up(20231201101059)
          migrator.up(20231201101060)
          migrator.up(20231201101061)

          assert_equal 20231201101061, migrator.current_version
          assert_not migrator.needs_migration?
        end
      end
    ensure
      File.delete(*Dir[migrations_path_dest + "/*.rb"])
      Dir.rmdir(migrations_path_dest) if Dir.exist?(migrations_path_dest)
    end

    private
      def with_temp_migration_files(filenames, migrations_dir = @migrations_path)
        Dir.mkdir(migrations_dir) unless Dir.exist?(migrations_dir)

        paths = []
        filenames.each do |filename|
          path = File.join(migrations_dir, filename)
          paths << path

          migration_class = filename.match(ActiveRecord::Migration::MigrationFilenameRegexp)[2].camelize

          File.open(path, "w+") do |file|
            file << <<~MIGRATION
          class #{migration_class} < ActiveRecord::Migration::Current
            def change; end
          end
            MIGRATION
          end
        end

        yield
      ensure
        paths.each { |path| File.delete(path) if File.exist?(path) }
        Dir.rmdir(migrations_dir) if Dir.exist?(migrations_dir)
      end
  end
end
