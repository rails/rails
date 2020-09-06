# frozen_string_literal: true

require 'cases/helper'

class PostgresqlExtensionMigrationTest < ActiveRecord::PostgreSQLTestCase
  self.use_transactional_tests = false

  class EnableHstore < ActiveRecord::Migration::Current
    def change
      enable_extension 'hstore'
    end
  end

  class DisableHstore < ActiveRecord::Migration::Current
    def change
      disable_extension 'hstore'
    end
  end

  def setup
    super

    @connection = ActiveRecord::Base.connection

    @old_table_name_prefix = ActiveRecord::Base.table_name_prefix
    @old_table_name_suffix = ActiveRecord::Base.table_name_suffix

    ActiveRecord::Base.table_name_prefix = 'p_'
    ActiveRecord::Base.table_name_suffix = '_s'
    @connection.schema_migration.reset_table_name
    ActiveRecord::InternalMetadata.reset_table_name

    @connection.schema_migration.delete_all rescue nil
    ActiveRecord::Migration.verbose = false
  end

  def teardown
    @connection.schema_migration.delete_all rescue nil
    ActiveRecord::Migration.verbose = true

    ActiveRecord::Base.table_name_prefix = @old_table_name_prefix
    ActiveRecord::Base.table_name_suffix = @old_table_name_suffix
    @connection.schema_migration.reset_table_name
    ActiveRecord::InternalMetadata.reset_table_name

    super
  end

  def test_enable_extension_migration_ignores_prefix_and_suffix
    @connection.disable_extension('hstore')

    migrations = [EnableHstore.new(nil, 1)]
    ActiveRecord::Migrator.new(:up, migrations, ActiveRecord::Base.connection.schema_migration).migrate
    assert @connection.extension_enabled?('hstore'), 'extension hstore should be enabled'
  end

  def test_disable_extension_migration_ignores_prefix_and_suffix
    @connection.enable_extension('hstore')

    migrations = [DisableHstore.new(nil, 1)]
    ActiveRecord::Migrator.new(:up, migrations, ActiveRecord::Base.connection.schema_migration).migrate
    assert_not @connection.extension_enabled?('hstore'), 'extension hstore should not be enabled'
  end
end
