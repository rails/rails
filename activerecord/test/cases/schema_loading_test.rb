require "cases/helper"

class SchemaLoadingTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  setup do
    ActiveRecord::SchemaMigration.create_table
  end

  def test_assume_migrated_upto_version_gets_all_versions
    migrations_path = MIGRATIONS_ROOT + "/valid_with_subdirectories"

    ActiveRecord::Base.connection.assume_migrated_upto_version(3, migrations_path)
    assert_equal 3, ActiveRecord::Migrator.current_version

    sm_table = ActiveRecord::Migrator.schema_migrations_table_name
    migrated = ActiveRecord::Base.connection.select_values("SELECT version FROM #{sm_table}").map(&:to_i)
    assert_equal [1,2,3], migrated.sort
  end
end
