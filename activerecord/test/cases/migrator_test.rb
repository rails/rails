# frozen_string_literal: true

require "cases/helper"
require "cases/migration/helper"

class MigratorTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  # Use this class to sense if migrations have gone
  # up or down.
  class Sensor < ActiveRecord::Migration::Current
    attr_reader :went_up, :went_down

    def initialize(name = self.class.name, version = nil)
      super
      @went_up = false
      @went_down = false
    end

    def up; @went_up = true; end
    def down; @went_down = true; end
  end

  def setup
    super
    @schema_migration = ActiveRecord::Base.connection.schema_migration
    @schema_migration.create_table
    @schema_migration.delete_all rescue nil
    @verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.message_count = 0
    ActiveRecord::Migration.class_eval do
      undef :puts
      def puts(*)
        ActiveRecord::Migration.message_count += 1
      end
    end
  end

  teardown do
    @schema_migration.delete_all rescue nil
    ActiveRecord::Migration.verbose = @verbose_was
    ActiveRecord::Migration.class_eval do
      undef :puts
      def puts(*)
        super
      end
    end
  end

  def test_migrator_with_duplicate_names
    e = assert_raises(ActiveRecord::DuplicateMigrationNameError) do
      list = [ActiveRecord::Migration.new("Chunky"), ActiveRecord::Migration.new("Chunky")]
      ActiveRecord::Migrator.new(:up, list, @schema_migration)
    end
    assert_match(/Multiple migrations have the name Chunky/, e.message)
  end

  def test_migrator_with_duplicate_versions
    assert_raises(ActiveRecord::DuplicateMigrationVersionError) do
      list = [ActiveRecord::Migration.new("Foo", 1), ActiveRecord::Migration.new("Bar", 1)]
      ActiveRecord::Migrator.new(:up, list, @schema_migration)
    end
  end

  def test_migrator_with_missing_version_numbers
    assert_raises(ActiveRecord::UnknownMigrationVersionError) do
      list = [ActiveRecord::Migration.new("Foo", 1), ActiveRecord::Migration.new("Bar", 2)]
      ActiveRecord::Migrator.new(:up, list, @schema_migration, 3).run
    end

    assert_raises(ActiveRecord::UnknownMigrationVersionError) do
      list = [ActiveRecord::Migration.new("Foo", 1), ActiveRecord::Migration.new("Bar", 2)]
      ActiveRecord::Migrator.new(:up, list, @schema_migration, -1).run
    end

    assert_raises(ActiveRecord::UnknownMigrationVersionError) do
      list = [ActiveRecord::Migration.new("Foo", 1), ActiveRecord::Migration.new("Bar", 2)]
      ActiveRecord::Migrator.new(:up, list, @schema_migration, 0).run
    end

    assert_raises(ActiveRecord::UnknownMigrationVersionError) do
      list = [ActiveRecord::Migration.new("Foo", 1), ActiveRecord::Migration.new("Bar", 2)]
      ActiveRecord::Migrator.new(:up, list, @schema_migration, 3).migrate
    end

    assert_raises(ActiveRecord::UnknownMigrationVersionError) do
      list = [ActiveRecord::Migration.new("Foo", 1), ActiveRecord::Migration.new("Bar", 2)]
      ActiveRecord::Migrator.new(:up, list, @schema_migration, -1).migrate
    end
  end

  def test_finds_migrations
    schema_migration = ActiveRecord::Base.connection.schema_migration
    migrations = ActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/valid", schema_migration).migrations

    [[1, "ValidPeopleHaveLastNames"], [2, "WeNeedReminders"], [3, "InnocentJointable"]].each_with_index do |pair, i|
      assert_equal migrations[i].version, pair.first
      assert_equal migrations[i].name, pair.last
    end
  end

  def test_finds_migrations_in_subdirectories
    schema_migration = ActiveRecord::Base.connection.schema_migration
    migrations = ActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/valid_with_subdirectories", schema_migration).migrations

    [[1, "ValidPeopleHaveLastNames"], [2, "WeNeedReminders"], [3, "InnocentJointable"]].each_with_index do |pair, i|
      assert_equal migrations[i].version, pair.first
      assert_equal migrations[i].name, pair.last
    end
  end

  def test_finds_migrations_from_two_directories
    schema_migration = ActiveRecord::Base.connection.schema_migration
    directories = [MIGRATIONS_ROOT + "/valid_with_timestamps", MIGRATIONS_ROOT + "/to_copy_with_timestamps"]
    migrations = ActiveRecord::MigrationContext.new(directories, schema_migration).migrations

    [[20090101010101, "PeopleHaveHobbies"],
     [20090101010202, "PeopleHaveDescriptions"],
     [20100101010101, "ValidWithTimestampsPeopleHaveLastNames"],
     [20100201010101, "ValidWithTimestampsWeNeedReminders"],
     [20100301010101, "ValidWithTimestampsInnocentJointable"]].each_with_index do |pair, i|
       assert_equal pair.first, migrations[i].version
       assert_equal pair.last, migrations[i].name
     end
  end

  def test_finds_migrations_in_numbered_directory
    schema_migration = ActiveRecord::Base.connection.schema_migration
    migrations = ActiveRecord::MigrationContext.new(MIGRATIONS_ROOT + "/10_urban", schema_migration).migrations
    assert_equal 9, migrations[0].version
    assert_equal "AddExpressions", migrations[0].name
  end

  def test_relative_migrations
    schema_migration = ActiveRecord::Base.connection.schema_migration
    list = Dir.chdir(MIGRATIONS_ROOT) do
      ActiveRecord::MigrationContext.new("valid", schema_migration).migrations
    end

    migration_proxy = list.find { |item|
      item.name == "ValidPeopleHaveLastNames"
    }
    assert migration_proxy, "should find pending migration"
  end

  def test_finds_pending_migrations
    @schema_migration.create!(version: "1")
    migration_list = [ActiveRecord::Migration.new("foo", 1), ActiveRecord::Migration.new("bar", 3)]
    migrations = ActiveRecord::Migrator.new(:up, migration_list, @schema_migration).pending_migrations

    assert_equal 1, migrations.size
    assert_equal migration_list.last, migrations.first
  end

  def test_migrations_status
    path = MIGRATIONS_ROOT + "/valid"
    schema_migration = ActiveRecord::Base.connection.schema_migration

    @schema_migration.create(version: 2)
    @schema_migration.create(version: 10)

    assert_equal [
      ["down", "001", "Valid people have last names"],
      ["up",   "002", "We need reminders"],
      ["down", "003", "Innocent jointable"],
      ["up",   "010", "********** NO FILE **********"],
    ], ActiveRecord::MigrationContext.new(path, schema_migration).migrations_status
  end

  def test_migrations_status_in_subdirectories
    path = MIGRATIONS_ROOT + "/valid_with_subdirectories"
    schema_migration = ActiveRecord::Base.connection.schema_migration

    @schema_migration.create(version: 2)
    @schema_migration.create(version: 10)

    assert_equal [
      ["down", "001", "Valid people have last names"],
      ["up",   "002", "We need reminders"],
      ["down", "003", "Innocent jointable"],
      ["up",   "010", "********** NO FILE **********"],
    ], ActiveRecord::MigrationContext.new(path, schema_migration).migrations_status
  end

  def test_migrations_status_with_schema_define_in_subdirectories
    path = MIGRATIONS_ROOT + "/valid_with_subdirectories"
    prev_paths = ActiveRecord::Migrator.migrations_paths
    schema_migration = ActiveRecord::Base.connection.schema_migration
    ActiveRecord::Migrator.migrations_paths = path

    ActiveRecord::Schema.define(version: 3) do
    end

    assert_equal [
      ["up", "001", "Valid people have last names"],
      ["up", "002", "We need reminders"],
      ["up", "003", "Innocent jointable"],
    ], ActiveRecord::MigrationContext.new(path, schema_migration).migrations_status
  ensure
    ActiveRecord::Migrator.migrations_paths = prev_paths
  end

  def test_migrations_status_from_two_directories
    paths = [MIGRATIONS_ROOT + "/valid_with_timestamps", MIGRATIONS_ROOT + "/to_copy_with_timestamps"]
    schema_migration = ActiveRecord::Base.connection.schema_migration

    @schema_migration.create(version: "20100101010101")
    @schema_migration.create(version: "20160528010101")

    assert_equal [
      ["down", "20090101010101", "People have hobbies"],
      ["down", "20090101010202", "People have descriptions"],
      ["up",   "20100101010101", "Valid with timestamps people have last names"],
      ["down", "20100201010101", "Valid with timestamps we need reminders"],
      ["down", "20100301010101", "Valid with timestamps innocent jointable"],
      ["up",   "20160528010101", "********** NO FILE **********"],
    ], ActiveRecord::MigrationContext.new(paths, schema_migration).migrations_status
  end

  def test_migrator_interleaved_migrations
    pass_one = [Sensor.new("One", 1)]

    ActiveRecord::Migrator.new(:up, pass_one, @schema_migration).migrate
    assert pass_one.first.went_up
    assert_not pass_one.first.went_down

    pass_two = [Sensor.new("One", 1), Sensor.new("Three", 3)]
    ActiveRecord::Migrator.new(:up, pass_two, @schema_migration).migrate
    assert_not pass_two[0].went_up
    assert pass_two[1].went_up
    assert pass_two.all? { |x| !x.went_down }

    pass_three = [Sensor.new("One", 1),
                  Sensor.new("Two", 2),
                  Sensor.new("Three", 3)]

    ActiveRecord::Migrator.new(:down, pass_three, @schema_migration).migrate
    assert pass_three[0].went_down
    assert_not pass_three[1].went_down
    assert pass_three[2].went_down
  end

  def test_up_calls_up
    migrations = [Sensor.new(nil, 0), Sensor.new(nil, 1), Sensor.new(nil, 2)]
    migrator = ActiveRecord::Migrator.new(:up, migrations, @schema_migration)
    migrator.migrate
    assert migrations.all?(&:went_up)
    assert migrations.all? { |m| !m.went_down }
    assert_equal 2, migrator.current_version
  end

  def test_down_calls_down
    test_up_calls_up

    migrations = [Sensor.new(nil, 0), Sensor.new(nil, 1), Sensor.new(nil, 2)]
    migrator = ActiveRecord::Migrator.new(:down, migrations, @schema_migration)
    migrator.migrate
    assert migrations.all? { |m| !m.went_up }
    assert migrations.all?(&:went_down)
    assert_equal 0, migrator.current_version
  end

  def test_current_version
    @schema_migration.create!(version: "1000")
    schema_migration = ActiveRecord::Base.connection.schema_migration
    migrator = ActiveRecord::MigrationContext.new("db/migrate", schema_migration)
    assert_equal 1000, migrator.current_version
  end

  def test_migrator_one_up
    calls, migrations = sensors(3)

    ActiveRecord::Migrator.new(:up, migrations, @schema_migration, 1).migrate
    assert_equal [[:up, 1]], calls
    calls.clear

    ActiveRecord::Migrator.new(:up, migrations, @schema_migration, 2).migrate
    assert_equal [[:up, 2]], calls
  end

  def test_migrator_one_down
    calls, migrations = sensors(3)

    ActiveRecord::Migrator.new(:up, migrations, @schema_migration).migrate
    assert_equal [[:up, 1], [:up, 2], [:up, 3]], calls
    calls.clear

    ActiveRecord::Migrator.new(:down, migrations, @schema_migration, 1).migrate

    assert_equal [[:down, 3], [:down, 2]], calls
  end

  def test_migrator_one_up_one_down
    calls, migrations = sensors(3)

    ActiveRecord::Migrator.new(:up, migrations, @schema_migration, 1).migrate
    assert_equal [[:up, 1]], calls
    calls.clear

    ActiveRecord::Migrator.new(:down, migrations, @schema_migration, 0).migrate
    assert_equal [[:down, 1]], calls
  end

  def test_migrator_double_up
    calls, migrations = sensors(3)
    migrator = ActiveRecord::Migrator.new(:up, migrations, @schema_migration, 1)
    assert_equal(0, migrator.current_version)

    migrator.migrate
    assert_equal [[:up, 1]], calls
    calls.clear

    migrator.migrate
    assert_equal [], calls
  end

  def test_migrator_double_down
    calls, migrations = sensors(3)
    migrator = ActiveRecord::Migrator.new(:up, migrations, @schema_migration, 1)

    assert_equal 0, migrator.current_version

    migrator.run
    assert_equal [[:up, 1]], calls
    calls.clear

    migrator = ActiveRecord::Migrator.new(:down, migrations, @schema_migration, 1)
    migrator.run
    assert_equal [[:down, 1]], calls
    calls.clear

    migrator.run
    assert_equal [], calls

    assert_equal 0, migrator.current_version
  end

  def test_migrator_verbosity
    _, migrations = sensors(3)

    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.new(:up, migrations, @schema_migration, 1).migrate
    assert_not_equal 0, ActiveRecord::Migration.message_count

    ActiveRecord::Migration.message_count = 0

    ActiveRecord::Migrator.new(:down, migrations, @schema_migration, 0).migrate
    assert_not_equal 0, ActiveRecord::Migration.message_count
  end

  def test_migrator_verbosity_off
    _, migrations = sensors(3)

    ActiveRecord::Migration.verbose = false
    ActiveRecord::Migrator.new(:up, migrations, @schema_migration, 1).migrate
    assert_equal 0, ActiveRecord::Migration.message_count
    ActiveRecord::Migrator.new(:down, migrations, @schema_migration, 0).migrate
    assert_equal 0, ActiveRecord::Migration.message_count
  end

  def test_target_version_zero_should_run_only_once
    calls, migrations = sensors(3)

    # migrate up to 1
    ActiveRecord::Migrator.new(:up, migrations, @schema_migration, 1).migrate
    assert_equal [[:up, 1]], calls
    calls.clear

    # migrate down to 0
    ActiveRecord::Migrator.new(:down, migrations, @schema_migration, 0).migrate
    assert_equal [[:down, 1]], calls
    calls.clear

    # migrate down to 0 again
    ActiveRecord::Migrator.new(:down, migrations, @schema_migration, 0).migrate
    assert_equal [], calls
  end

  def test_migrator_going_down_due_to_version_target
    schema_migration = ActiveRecord::Base.connection.schema_migration
    calls, migrator = migrator_class(3)
    migrator = migrator.new("valid", schema_migration)

    migrator.up(1)
    assert_equal [[:up, 1]], calls
    calls.clear

    migrator.migrate(0)
    assert_equal [[:down, 1]], calls
    calls.clear

    migrator.migrate
    assert_equal [[:up, 1], [:up, 2], [:up, 3]], calls
  end

  def test_migrator_output_when_running_multiple_migrations
    schema_migration = ActiveRecord::Base.connection.schema_migration
    _, migrator = migrator_class(3)
    migrator = migrator.new("valid", schema_migration)

    result = migrator.migrate
    assert_equal(3, result.count)

    # Nothing migrated from duplicate run
    result = migrator.migrate
    assert_equal(0, result.count)

    result = migrator.rollback
    assert_equal(1, result.count)
  end

  def test_migrator_output_when_running_single_migration
    schema_migration = ActiveRecord::Base.connection.schema_migration
    _, migrator = migrator_class(1)
    migrator = migrator.new("valid", schema_migration)

    result = migrator.run(:up, 1)

    assert_equal(1, result.version)
  end

  def test_migrator_rollback
    schema_migration = ActiveRecord::Base.connection.schema_migration
    _, migrator = migrator_class(3)
    migrator = migrator.new("valid", schema_migration)

    migrator.migrate
    assert_equal(3, migrator.current_version)

    migrator.rollback
    assert_equal(2, migrator.current_version)

    migrator.rollback
    assert_equal(1, migrator.current_version)

    migrator.rollback
    assert_equal(0, migrator.current_version)

    migrator.rollback
    assert_equal(0, migrator.current_version)
  end

  def test_migrator_db_has_no_schema_migrations_table
    schema_migration = ActiveRecord::Base.connection.schema_migration
    _, migrator = migrator_class(3)
    migrator = migrator.new("valid", schema_migration)

    ActiveRecord::SchemaMigration.drop_table
    assert_not_predicate ActiveRecord::SchemaMigration, :table_exists?
    migrator.migrate(1)
    assert_predicate ActiveRecord::SchemaMigration, :table_exists?
  end

  def test_migrator_forward
    schema_migration = ActiveRecord::Base.connection.schema_migration
    _, migrator = migrator_class(3)
    migrator = migrator.new("/valid", schema_migration)
    migrator.migrate(1)
    assert_equal(1, migrator.current_version)

    migrator.forward(2)
    assert_equal(3, migrator.current_version)

    migrator.forward
    assert_equal(3, migrator.current_version)
  end

  def test_only_loads_pending_migrations
    # migrate up to 1
    @schema_migration.create!(version: "1")

    schema_migration = ActiveRecord::Base.connection.schema_migration
    calls, migrator = migrator_class(3)
    migrator = migrator.new("valid", schema_migration)
    migrator.migrate

    assert_equal [[:up, 2], [:up, 3]], calls
  end

  def test_get_all_versions
    schema_migration = ActiveRecord::Base.connection.schema_migration
    _, migrator = migrator_class(3)
    migrator = migrator.new("valid", schema_migration)

    migrator.migrate
    assert_equal([1, 2, 3], migrator.get_all_versions)

    migrator.rollback
    assert_equal([1, 2], migrator.get_all_versions)

    migrator.rollback
    assert_equal([1], migrator.get_all_versions)

    migrator.rollback
    assert_equal([], migrator.get_all_versions)
  end

  private
    def m(name, version)
      x = Sensor.new name, version
      x.extend(Module.new {
        define_method(:up) { yield(:up, x); super() }
        define_method(:down) { yield(:down, x); super() }
      }) if block_given?
    end

    def sensors(count)
      calls = []
      migrations = count.times.map { |i|
        m(nil, i + 1) { |c, migration|
          calls << [c, migration.version]
        }
      }
      [calls, migrations]
    end

    def migrator_class(count)
      calls, migrations = sensors(count)

      migrator = Class.new(ActiveRecord::MigrationContext) {
        define_method(:migrations) { |*|
          migrations
        }
      }
      [calls, migrator]
    end
end
