require "cases/helper"

class SchemaLoadingTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  setup do
    ActiveRecord::SchemaMigration.drop_table
    ActiveRecord::SchemaMigration.create_table
  end

  teardown do
    ActiveRecord::SchemaMigration.drop_table
  end

  def test_assume_migrated_upto_version_gets_all_versions
    migrations_path = MIGRATIONS_ROOT + "/valid_with_subdirectories"

    ActiveRecord::Base.connection.assume_migrated_upto_version(3, migrations_path)
    assert_equal 3, ActiveRecord::Migrator.current_version

    sm_table = ActiveRecord::Migrator.schema_migrations_table_name
    migrated = ActiveRecord::Base.connection.select_values("SELECT version FROM #{sm_table}").map(&:to_i)
    assert_equal [1,2,3], migrated.sort
  end

  if current_adapter?(:SQLite3Adapter)
    %w{3.7.8 3.7.11 3.7.12}.each do |version_string|
      test "sql insertion for sqlite version #{version_string}" do
        version = ActiveRecord::ConnectionAdapters::SQLite3Adapter::Version.new(version_string)
        ActiveRecord::Base.connection.stubs(:sqlite_version).returns(version)

        sm_table = ActiveRecord::Migrator.schema_migrations_table_name
        connection = ActiveRecord::Base.connection

        versions = [20160101010101, 20160201010101, 20160301010101]
        sql = connection.insert_versions_sql versions
        connection.execute_multi_insert sql

        inserted = connection.select_values("SELECT version FROM #{sm_table}").map(&:to_i)
        assert_equal versions.sort, inserted.sort
      end
    end
  end
end
