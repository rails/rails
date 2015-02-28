require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class AbstractMysqlAdapter
      class SchemaMigrationsTest < ActiveRecord::TestCase
        def test_renaming_index_on_foreign_key
          connection.add_index "engines", "car_id"
          connection.add_foreign_key :engines, :cars, name: "fk_engines_cars"

          connection.rename_index("engines", "index_engines_on_car_id", "idx_renamed")
          assert_equal ["idx_renamed"], connection.indexes("engines").map(&:name)
        ensure
          connection.remove_foreign_key :engines, name: "fk_engines_cars"
        end

        def test_initializes_schema_migrations_for_encoding_utf8mb4
          smtn = ActiveRecord::Migrator.schema_migrations_table_name
          connection.drop_table smtn, if_exists: true

          database_name = connection.current_database
          database_info = connection.select_one("SELECT * FROM information_schema.schemata WHERE schema_name = '#{database_name}'")

          original_charset = database_info["DEFAULT_CHARACTER_SET_NAME"]
          original_collation = database_info["DEFAULT_COLLATION_NAME"]

          execute("ALTER DATABASE #{database_name} DEFAULT CHARACTER SET utf8mb4")

          connection.initialize_schema_migrations_table

          assert connection.column_exists?(smtn, :version, :string, limit: AbstractMysqlAdapter::MAX_INDEX_LENGTH_FOR_CHARSETS_OF_4BYTES_MAXLEN)
        ensure
          execute("ALTER DATABASE #{database_name} DEFAULT CHARACTER SET #{original_charset} COLLATE #{original_collation}")
        end

        private
        def connection
          @connection ||= ActiveRecord::Base.connection
        end

        def execute(sql)
          connection.execute(sql)
        end
      end
    end
  end
end
