# frozen_string_literal: true

require "cases/helper"

class PostgresqlExtensionMigrationTest < ActiveRecord::PostgreSQLTestCase
  self.use_transactional_tests = false

  class EnableHstore < ActiveRecord::Migration::Current
    def change
      enable_extension "hstore"
    end
  end

  class DisableHstore < ActiveRecord::Migration::Current
    def change
      disable_extension "hstore"
    end
  end

  class EnableHstoreInSchema < ActiveRecord::Migration::Current
    def change
      enable_extension "hstore", schema: "other_schema"
    end
  end

  class DisableHstoreInSchema < ActiveRecord::Migration::Current
    def change
      disable_extension "hstore", schema: "other_schema"
    end
  end

  class EnableSchemaQualifiedHstore < ActiveRecord::Migration::Current
    def change
      enable_extension "other_schema.hstore"
    end
  end

  class EnableSchemaQualifiedHstoreOn8_1 < ActiveRecord::Migration[8.1]
    def change
      enable_extension "other_schema.hstore"
    end
  end

  class DisableSchemaQualifiedHstoreOn8_1 < ActiveRecord::Migration[8.1]
    def change
      disable_extension "other_schema.hstore"
    end
  end

  def setup
    super

    @connection = ActiveRecord::Base.lease_connection
    @pool = ActiveRecord::Base.connection_pool

    @old_table_name_prefix = ActiveRecord::Base.table_name_prefix
    @old_table_name_suffix = ActiveRecord::Base.table_name_suffix

    ActiveRecord::Base.table_name_prefix = "p_"
    ActiveRecord::Base.table_name_suffix = "_s"

    @pool.schema_migration.delete_all_versions rescue nil
    ActiveRecord::Migration.verbose = false
  end

  def teardown
    @pool.schema_migration.delete_all_versions rescue nil
    ActiveRecord::Migration.verbose = true

    ActiveRecord::Base.table_name_prefix = @old_table_name_prefix
    ActiveRecord::Base.table_name_suffix = @old_table_name_suffix

    super
  end

  def test_enable_extension_migration_ignores_prefix_and_suffix
    @connection.disable_extension("hstore")

    migrations = [EnableHstore.new(nil, 1)]
    ActiveRecord::Migrator.new(:up, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    assert @connection.extension_enabled?("hstore"), "extension hstore should be enabled"
  end

  def test_enable_extension_migration_with_schema
    @connection.disable_extension("hstore")
    @connection.create_schema "other_schema"

    migrations = [EnableHstoreInSchema.new(nil, 1)]
    assert_not_deprecated(ActiveRecord.deprecator) do
      ActiveRecord::Migrator.new(:up, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    end

    assert @connection.extension_enabled?("hstore"), "extension hstore should be enabled"
    assert_includes @connection.extensions, "other_schema.hstore"

    ActiveRecord::Migrator.new(:down, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    assert_not @connection.extension_enabled?("hstore"), "extension hstore should not be enabled"
  ensure
    @connection.drop_schema "other_schema", if_exists: true
  end

  def test_disable_extension_migration_with_schema_drops_by_name_and_reverts_into_the_schema
    @connection.disable_extension("hstore")
    @connection.create_schema "other_schema"
    @connection.enable_extension("hstore")

    migrations = [DisableHstoreInSchema.new(nil, 1)]
    assert_not_deprecated(ActiveRecord.deprecator) do
      ActiveRecord::Migrator.new(:up, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    end
    assert_not @connection.extension_enabled?("hstore"), "extension hstore should not be enabled"

    ActiveRecord::Migrator.new(:down, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    assert_includes @connection.extensions, "other_schema.hstore"
  ensure
    @connection.disable_extension("hstore")
    @connection.drop_schema "other_schema", if_exists: true
  end

  def test_enable_extension_migration_with_schema_qualified_name_is_deprecated
    @connection.disable_extension("hstore")
    @connection.create_schema "other_schema"

    migrations = [EnableSchemaQualifiedHstore.new(nil, 1)]
    assert_deprecated(/`enable_extension`.*`"hstore", schema: "other_schema"`/, ActiveRecord.deprecator) do
      ActiveRecord::Migrator.new(:up, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    end

    assert_includes @connection.extensions, "other_schema.hstore"

    assert_deprecated(/`disable_extension`.*`"hstore", schema: "other_schema"`/, ActiveRecord.deprecator) do
      ActiveRecord::Migrator.new(:down, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    end
    assert_not @connection.extension_enabled?("hstore"), "extension hstore should not be enabled"
  ensure
    @connection.drop_schema "other_schema", if_exists: true
  end

  def test_enable_extension_migration_with_schema_qualified_name_on_8_1_is_not_deprecated
    @connection.disable_extension("hstore")
    @connection.create_schema "other_schema"

    migrations = [EnableSchemaQualifiedHstoreOn8_1.new(nil, 1)]
    assert_not_deprecated(ActiveRecord.deprecator) do
      ActiveRecord::Migrator.new(:up, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    end

    assert_includes @connection.extensions, "other_schema.hstore"

    assert_not_deprecated(ActiveRecord.deprecator) do
      ActiveRecord::Migrator.new(:down, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    end
    assert_not @connection.extension_enabled?("hstore"), "extension hstore should not be enabled"
  ensure
    @connection.drop_schema "other_schema", if_exists: true
  end

  def test_disable_extension_migration_with_schema_qualified_name_on_8_1_reverts_into_the_schema
    @connection.disable_extension("hstore")
    @connection.create_schema "other_schema"
    @connection.enable_extension("hstore", schema: "other_schema")

    migrations = [DisableSchemaQualifiedHstoreOn8_1.new(nil, 1)]
    assert_not_deprecated(ActiveRecord.deprecator) do
      ActiveRecord::Migrator.new(:up, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    end
    assert_not @connection.extension_enabled?("hstore"), "extension hstore should not be enabled"

    assert_not_deprecated(ActiveRecord.deprecator) do
      ActiveRecord::Migrator.new(:down, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    end
    assert_includes @connection.extensions, "other_schema.hstore"
  ensure
    @connection.disable_extension("hstore")
    @connection.drop_schema "other_schema", if_exists: true
  end

  def test_schema_define_with_schema_qualified_extension_name_on_8_1_is_not_deprecated
    @connection.disable_extension("hstore")
    @connection.create_schema "other_schema"

    assert_not_deprecated(ActiveRecord.deprecator) do
      ActiveRecord::Schema[8.1].define do
        enable_extension "other_schema.hstore"
      end
    end

    assert_includes @connection.extensions, "other_schema.hstore"
  ensure
    @connection.disable_extension("hstore")
    @connection.drop_schema "other_schema", if_exists: true
  end


  def test_disable_extension_migration_ignores_prefix_and_suffix
    @connection.enable_extension("hstore")

    migrations = [DisableHstore.new(nil, 1)]
    ActiveRecord::Migrator.new(:up, migrations, @pool.schema_migration, @pool.internal_metadata).migrate
    assert_not @connection.extension_enabled?("hstore"), "extension hstore should not be enabled"
  end

  def test_disable_extension_raises_when_dependent_objects_exist
    @connection.enable_extension("hstore")
    @connection.create_table(:hstores) do |t|
      t.hstore :settings
    end

    error = assert_raises(StandardError) do
      @connection.disable_extension(:hstore)
    end
    assert_match(/cannot drop extension hstore because other objects depend on it/i, error.message)
  ensure
    @connection.drop_table(:hstores, if_exists: true)
  end

  def test_disable_extension_drops_extension_when_cascading
    @connection.enable_extension("hstore")
    @connection.create_table(:hstores) do |t|
      t.hstore :settings
    end

    @connection.disable_extension(:hstore, force: :cascade)
    assert_not @connection.extension_enabled?("hstore"), "extension hstore should not be enabled"
  ensure
    @connection.drop_table(:hstores, if_exists: true)
  end
end
