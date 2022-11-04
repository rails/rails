# frozen_string_literal: true

require "cases/helper"
require "cases/migration/helper"

class MultiDbMigratorTest < ActiveRecord::TestCase
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
    @connection_a = ActiveRecord::Base.connection
    @connection_b = ARUnit2Model.connection

    @connection_a.schema_migration.create_table
    @connection_b.schema_migration.create_table

    @connection_a.schema_migration.delete_all_versions rescue nil
    @connection_b.schema_migration.delete_all_versions rescue nil

    @path_a = MIGRATIONS_ROOT + "/valid"
    @path_b = MIGRATIONS_ROOT + "/to_copy"

    @schema_migration_a = @connection_a.schema_migration
    @internal_metadata_a = @connection_a.internal_metadata
    @migrations_a = ActiveRecord::MigrationContext.new(@path_a, @schema_migration_a, @internal_metadata_a).migrations

    @schema_migration_b = @connection_b.schema_migration
    @internal_metadata_b = @connection_b.internal_metadata
    @migrations_b = ActiveRecord::MigrationContext.new(@path_b, @schema_migration_b, @internal_metadata_b).migrations

    @migrations_a_list = [[1, "ValidPeopleHaveLastNames"], [2, "WeNeedReminders"], [3, "InnocentJointable"]]
    @migrations_b_list = [[1, "PeopleHaveHobbies"], [2, "PeopleHaveDescriptions"]]

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
    @connection_a.schema_migration.delete_all_versions rescue nil
    @connection_b.schema_migration.delete_all_versions rescue nil

    ActiveRecord::Migration.verbose = @verbose_was
    ActiveRecord::Migration.class_eval do
      undef :puts
      def puts(*)
        super
      end
    end
  end

  def test_schema_migration_is_different_for_different_connections
    assert_not_equal @schema_migration_a, @schema_migration_b
    assert_not_equal @schema_migration_a.connection, @schema_migration_b.connection
    assert_equal "ActiveRecord::Base", @schema_migration_a.connection.pool.pool_config.connection_name
    assert_equal "ARUnit2Model", @schema_migration_b.connection.pool.pool_config.connection_name
  end

  def test_finds_migrations
    @migrations_a_list.each_with_index do |pair, i|
      assert_equal @migrations_a[i].version, pair.first
      assert_equal @migrations_a[i].name, pair.last
    end

    @migrations_b_list.each_with_index do |pair, i|
      assert_equal @migrations_b[i].version, pair.first
      assert_equal @migrations_b[i].name, pair.last
    end
  end

  def test_migrations_status
    @schema_migration_a.create_version(2)
    @schema_migration_a.create_version(10)

    assert_equal [
      ["down", "001", "Valid people have last names"],
      ["up",   "002", "We need reminders"],
      ["down", "003", "Innocent jointable"],
      ["up",   "010", "********** NO FILE **********"],
    ], ActiveRecord::MigrationContext.new(@path_a, @schema_migration_a, @internal_metadata_a).migrations_status

    @schema_migration_b.create_version(4)

    assert_equal [
      ["down", "001", "People have hobbies"],
      ["down", "002", "People have descriptions"],
      ["up", "004", "********** NO FILE **********"]
    ], ActiveRecord::MigrationContext.new(@path_b, @schema_migration_b, @internal_metadata_b).migrations_status
  end

  def test_get_all_versions
    _, migrator_a = migrator_class(3)
    migrator_a = migrator_a.new(@path_a, @schema_migration_a)

    migrator_a.migrate
    assert_equal([1, 2, 3], migrator_a.get_all_versions)

    migrator_a.rollback
    assert_equal([1, 2], migrator_a.get_all_versions)

    migrator_a.rollback
    assert_equal([1], migrator_a.get_all_versions)

    migrator_a.rollback
    assert_equal([], migrator_a.get_all_versions)

    _, migrator_b = migrator_class(2)
    migrator_b = migrator_b.new(@path_b, @schema_migration_b)

    migrator_b.migrate
    assert_equal([1, 2], migrator_b.get_all_versions)

    migrator_b.rollback
    assert_equal([1], migrator_b.get_all_versions)

    migrator_b.rollback
    assert_equal([], migrator_b.get_all_versions)
  end

  def test_finds_pending_migrations
    @schema_migration_a.create_version("1")
    migration_list_a = [ActiveRecord::Migration.new("foo", 1), ActiveRecord::Migration.new("bar", 3)]
    migrations_a = ActiveRecord::Migrator.new(:up, migration_list_a, @schema_migration_a, @internal_metadata_a).pending_migrations

    assert_equal 1, migrations_a.size
    assert_equal migration_list_a.last, migrations_a.first

    @schema_migration_b.create_version("1")
    migration_list_b = [ActiveRecord::Migration.new("foo", 1), ActiveRecord::Migration.new("bar", 3)]
    migrations_b = ActiveRecord::Migrator.new(:up, migration_list_b, @schema_migration_b, @internal_metadata_b).pending_migrations

    assert_equal 1, migrations_b.size
    assert_equal migration_list_b.last, migrations_b.first
  end

  def test_migrator_db_has_no_schema_migrations_table
    _, migrator = migrator_class(3)
    migrator = migrator.new(@path_a, @schema_migration_a, @internal_metadata_a)

    @schema_migration_a.drop_table
    assert_not @connection_a.table_exists?("schema_migrations")
    migrator.migrate(1)
    assert @connection_a.table_exists?("schema_migrations")

    _, migrator = migrator_class(3)
    migrator = migrator.new(@path_b, @schema_migration_b, @internal_metadata_b)

    @schema_migration_b.drop_table
    assert_not @connection_b.table_exists?("schema_migrations")
    migrator.migrate(1)
    assert @connection_b.table_exists?("schema_migrations")
  end

  def test_migrator_forward
    _, migrator = migrator_class(3)
    migrator = migrator.new(@path_a, @schema_migration_a, @internal_metadata_a)
    migrator.migrate(1)
    assert_equal(1, migrator.current_version)

    migrator.forward(2)
    assert_equal(3, migrator.current_version)

    migrator.forward
    assert_equal(3, migrator.current_version)

    _, migrator_b = migrator_class(3)
    migrator_b = migrator_b.new(@path_b, @schema_migration_b, @internal_metadata_b)
    migrator_b.migrate(1)
    assert_equal(1, migrator_b.current_version)

    migrator_b.forward(2)
    assert_equal(3, migrator_b.current_version)

    migrator_b.forward
    assert_equal(3, migrator_b.current_version)
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
