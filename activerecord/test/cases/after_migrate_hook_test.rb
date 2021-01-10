# frozen_string_literal: true

require "cases/helper"
require "cases/migration/helper"

require "models/person"

class Reminder < ActiveRecord::Base; end

class AfterMigrateHookTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def setup
    super
    %w(reminders people_reminders prefix_reminders_suffix p_things_s).each do |table|
      Reminder.connection.drop_table(table) rescue nil
    end
    Reminder.reset_column_information

    @verbose_was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false
    @schema_migration = ActiveRecord::Base.connection.schema_migration
    ActiveRecord::Base.connection.schema_cache.clear!

    @log = ""
    ActiveRecord::Migration.after_migrate_hook = -> (log, name, direction, error) do
      @log += "#{name} #{direction} #{error&.message}\n#{log}"
    end
  end

  teardown do
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""

    ActiveRecord::SchemaMigration.create_table
    ActiveRecord::SchemaMigration.delete_all

    %w(reminders people_reminders prefix_reminders_suffix).each do |table|
      Reminder.connection.drop_table(table) rescue nil
    end
    Reminder.reset_table_name
    Reminder.reset_column_information

    %w(last_name key bio age height wealth birthday favorite_day
       moment_of_truth male administrator funny).each do |column|
      Person.connection.remove_column("people", column) rescue nil
    end
    Person.connection.remove_column("people", "first_name") rescue nil
    Person.connection.remove_column("people", "middle_name") rescue nil
    Person.connection.add_column("people", "first_name", :string)
    Person.reset_column_information

    ActiveRecord::Migration.verbose = @verbose_was
    ActiveRecord::Migration.after_migrate_hook = nil
  end

  def test_after_migrate_hook_with_valid_migration
    migrations_path = MIGRATIONS_ROOT + "/valid"
    migrator = ActiveRecord::MigrationContext.new(migrations_path, @schema_migration)

    migrator.up
    assert_match(/\AValidPeopleHaveLastNames up \n== 1 ValidPeopleHaveLastNames: migrating ======================================\n-- add_column\("people", "last_name", :string\)\n   -> .+s\n== 1 ValidPeopleHaveLastNames: migrated \(.+s\) =============================\n\nWeNeedReminders up \n== 2 WeNeedReminders: migrating ===============================================\n-- create_table\("reminders"\)\n   -> .+s\n== 2 WeNeedReminders: migrated \(.+s\) ======================================\n\nInnocentJointable up \n== 3 InnocentJointable: migrating =============================================\n-- create_table\("people_reminders", {:id=>false}\)\n   -> .+s\n== 3 InnocentJointable: migrated \(.+s\) ====================================\n\n\z/, @log)
    @log = ""

    migrator.down
    assert_match(/\AInnocentJointable down \n== 3 InnocentJointable: reverting =============================================\n-- drop_table\("people_reminders"\)\n   -> .+s\n== 3 InnocentJointable: reverted \(.+s\) ====================================\n\nWeNeedReminders down \n== 2 WeNeedReminders: reverting ===============================================\n-- drop_table\("reminders"\)\n   -> .+s\n== 2 WeNeedReminders: reverted \(.+s\) ======================================\n\nValidPeopleHaveLastNames down \n== 1 ValidPeopleHaveLastNames: reverting ======================================\n-- remove_column\("people", "last_name"\)\n   -> .+s\n== 1 ValidPeopleHaveLastNames: reverted \(.+s\) =============================\n\n\z/, @log)
    @log = ""
  end

  def test_after_migrate_hook_with_error_migration
    migrations_path = MIGRATIONS_ROOT + "/error"
    error = assert_raises StandardError do
      migrator = ActiveRecord::MigrationContext.new(migrations_path, @schema_migration)
      migrator.up
    end

    assert_equal "An error has occurred, this and all later migrations canceled:\n\ndivided by 0", error.message

    assert_match(/\AErrorDivisionByZero up divided by 0\n== 1 ErrorDivisionByZero: migrating ===========================================\n\z/, @log)
    @log = ""
  end

  def test_migration_works_even_with_error_in_after_migrate_hook
    before = ActiveRecord::Migration.after_migrate_hook

    ActiveRecord::Migration.after_migrate_hook = -> (log, name, direction, error) do
      raise "error in after_migrate_hook"
    end

    migrations_path = MIGRATIONS_ROOT + "/valid"
    migrator = ActiveRecord::MigrationContext.new(migrations_path, @schema_migration)

    migrator.up
    assert_equal 3, migrator.current_version
    assert_equal false, migrator.needs_migration?

    ActiveRecord::Migration.after_migrate_hook = before
  end
end
