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
  end
end
