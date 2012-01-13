require "cases/helper"

module ActiveRecord
  class MigratorTest < ActiveRecord::TestCase
    def test_migrator_with_duplicate_names
      assert_raises(ActiveRecord::DuplicateMigrationNameError, "Multiple migrations have the name Chunky") do
        list = [Migration.new('Chunky'), Migration.new('Chunky')]
        ActiveRecord::Migrator.new(:up, list)
      end
    end

    def test_migrator_with_duplicate_versions
      assert_raises(ActiveRecord::DuplicateMigrationVersionError) do
        list = [Migration.new('Foo', 1), Migration.new('Bar', 1)]
        ActiveRecord::Migrator.new(:up, list)
      end
    end

    def test_migrator_with_missing_version_numbers
      assert_raises(ActiveRecord::UnknownMigrationVersionError) do
        list = [Migration.new('Foo', 1), Migration.new('Bar', 2)]
        ActiveRecord::Migrator.new(:up, list, 3).run
      end
    end

    def test_finds_migrations
      migrations = ActiveRecord::Migrator.migrations(MIGRATIONS_ROOT + "/valid")

      [[1, 'ValidPeopleHaveLastNames'], [2, 'WeNeedReminders'], [3, 'InnocentJointable']].each_with_index do |pair, i|
        assert_equal migrations[i].version, pair.first
        assert_equal migrations[i].name, pair.last
      end
    end

    def test_finds_migrations_in_subdirectories
      migrations = ActiveRecord::Migrator.migrations(MIGRATIONS_ROOT + "/valid_with_subdirectories")

      [[1, 'ValidPeopleHaveLastNames'], [2, 'WeNeedReminders'], [3, 'InnocentJointable']].each_with_index do |pair, i|
        assert_equal migrations[i].version, pair.first
        assert_equal migrations[i].name, pair.last
      end
    end

    def test_finds_migrations_from_two_directories
      directories = [MIGRATIONS_ROOT + '/valid_with_timestamps', MIGRATIONS_ROOT + '/to_copy_with_timestamps']
      migrations = ActiveRecord::Migrator.migrations directories

      [[20090101010101, "PeopleHaveHobbies"],
       [20090101010202, "PeopleHaveDescriptions"],
       [20100101010101, "ValidWithTimestampsPeopleHaveLastNames"],
       [20100201010101, "ValidWithTimestampsWeNeedReminders"],
       [20100301010101, "ValidWithTimestampsInnocentJointable"]].each_with_index do |pair, i|
        assert_equal pair.first, migrations[i].version
        assert_equal pair.last, migrations[i].name
       end
    end

    def test_deprecated_constructor
      assert_deprecated do
        ActiveRecord::Migrator.new(:up, MIGRATIONS_ROOT + "/interleaved/pass_2")
      end
    end

    def test_relative_migrations
      list = Dir.chdir(MIGRATIONS_ROOT) do
        ActiveRecord::Migrator.migrations("valid/")
      end

      migration_proxy = list.find { |item|
        item.name == 'ValidPeopleHaveLastNames'
      }
      assert migration_proxy, 'should find pending migration'
    end

    def test_finds_pending_migrations
      ActiveRecord::SchemaMigration.create!(:version => '1')
      migration_list = [ Migration.new('foo', 1), Migration.new('bar', 3) ]
      migrations = ActiveRecord::Migrator.new(:up, migration_list).pending_migrations

      assert_equal 1, migrations.size
      assert_equal migration_list.last, migrations.first
    end
  end
end
