require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class Mysql2Adapter
      class SchemaMigrationsTest < ActiveRecord::TestCase
        def test_renaming_index_on_foreign_key
          connection.add_index "engines", "car_id"
          connection.execute "ALTER TABLE engines ADD CONSTRAINT fk_engines_cars FOREIGN KEY (car_id) REFERENCES cars(id)"

          connection.rename_index("engines", "index_engines_on_car_id", "idx_renamed")
          assert_equal ["idx_renamed"], connection.indexes("engines").map(&:name)
        ensure
          connection.execute "ALTER TABLE engines DROP FOREIGN KEY fk_engines_cars"
        end

        def test_initializes_schema_migrations_for_encoding_utf8mb4
          smtn = ActiveRecord::Migrator.schema_migrations_table_name
          connection.drop_table(smtn) if connection.table_exists?(smtn)

          config = connection.instance_variable_get(:@config)
          original_encoding = config[:encoding]

          config[:encoding] = 'utf8mb4'
          connection.initialize_schema_migrations_table

          assert connection.column_exists?(smtn, :version, :string, limit: Mysql2Adapter::MAX_INDEX_LENGTH_FOR_UTF8MB4)
        ensure
          config[:encoding] = original_encoding
        end

        private
        def connection
          @connection ||= ActiveRecord::Base.connection
        end
      end
    end
  end
end
