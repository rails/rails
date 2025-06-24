# frozen_string_literal: true

require "cases/helper"

class SchemaMigrationsTest < ActiveRecord::AbstractMysqlTestCase
  def setup
    @pool = ActiveRecord::Base.connection_pool
    @schema_migration = @pool.schema_migration
  end

  def test_renaming_index_on_foreign_key
    connection.add_index "engines", "car_id"
    connection.add_foreign_key :engines, :cars, name: "fk_engines_cars"

    connection.rename_index("engines", "index_engines_on_car_id", "idx_renamed")
    assert_equal ["idx_renamed"], connection.indexes("engines").map(&:name)
  ensure
    connection.remove_foreign_key :engines, name: "fk_engines_cars"
  end

  def test_initializes_schema_migrations_for_encoding_utf8mb4
    with_encoding_utf8mb4 do
      table_name = @schema_migration.table_name
      connection.drop_table table_name, if_exists: true

      @schema_migration.create_table

      assert connection.column_exists?(table_name, :version, :string)
    end
  end

  def test_initializes_internal_metadata_for_encoding_utf8mb4
    with_encoding_utf8mb4 do
      internal_metadata = @pool.internal_metadata
      table_name = internal_metadata.table_name
      connection.drop_table table_name, if_exists: true

      internal_metadata.create_table

      assert connection.column_exists?(table_name, :key, :string)
    end
  ensure
    @pool.internal_metadata[:environment] = @pool.migration_context.current_environment
  end

  private
    def with_encoding_utf8mb4
      database_name = connection.current_database
      database_info = connection.select_one("SELECT * FROM information_schema.schemata WHERE schema_name = '#{database_name}'")

      original_charset = database_info["DEFAULT_CHARACTER_SET_NAME"]
      original_collation = database_info["DEFAULT_COLLATION_NAME"]

      execute("ALTER DATABASE #{database_name} DEFAULT CHARACTER SET utf8mb4")

      yield
    ensure
      execute("ALTER DATABASE #{database_name} DEFAULT CHARACTER SET #{original_charset} COLLATE #{original_collation}")
    end

    def connection
      @connection ||= ActiveRecord::Base.lease_connection
    end

    def execute(sql)
      connection.execute(sql)
    end
end
