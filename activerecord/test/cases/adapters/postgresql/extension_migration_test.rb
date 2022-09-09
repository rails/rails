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

  def setup
    super

    @connection = ActiveRecord::Base.connection

    @old_table_name_prefix = ActiveRecord::Base.table_name_prefix
    @old_table_name_suffix = ActiveRecord::Base.table_name_suffix

    ActiveRecord::Base.table_name_prefix = "p_"
    ActiveRecord::Base.table_name_suffix = "_s"
    @connection.internal_metadata.reset_table_name

    @connection.schema_migration.delete_all_versions rescue nil
    ActiveRecord::Migration.verbose = false
  end

  def teardown
    @connection.schema_migration.delete_all_versions rescue nil
    ActiveRecord::Migration.verbose = true

    ActiveRecord::Base.table_name_prefix = @old_table_name_prefix
    ActiveRecord::Base.table_name_suffix = @old_table_name_suffix
    @connection.internal_metadata.reset_table_name

    super
  end

  def test_enable_extension_migration_ignores_prefix_and_suffix
    @connection.disable_extension("hstore")

    migrations = [EnableHstore.new(nil, 1)]
    ActiveRecord::Migrator.new(:up, migrations, @connection.schema_migration, @connection.internal_metadata).migrate
    assert @connection.extension_enabled?("hstore"), "extension hstore should be enabled"
  end

  def test_disable_extension_migration_ignores_prefix_and_suffix
    @connection.enable_extension("hstore")

    migrations = [DisableHstore.new(nil, 1)]
    ActiveRecord::Migrator.new(:up, migrations, @connection.schema_migration, @connection.internal_metadata).migrate
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
