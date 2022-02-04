# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCacheTest < ActiveRecord::TestCase
        if current_adapter?(:PostgreSQLAdapter)
          def setup
            @connection = ActiveRecord::Base.connection
          end

          def test_type_map_existence_in_schema_cache
            assert_not(@connection.schema_cache.additional_type_records.empty?)
            assert_not(@connection.schema_cache.known_coder_type_records.empty?)
          end

          def test_type_map_queries_when_initialize_connection
            db_config = ActiveRecord::Base.configurations.configs_for(
              env_name: "arunit",
              name: "primary"
            )

            assert_no_sql("SELECT t.oid, t.typname") do
              ActiveRecord::Base.postgresql_connection(db_config.configuration_hash)
            end
          end

          def test_type_map_queries_with_custom_types
            cache = SchemaCache.new(@connection)
            tempfile = Tempfile.new(["schema_cache-", ".yml"])

            assert_no_sql("SELECT t.oid, t.typname") do
              cache.dump_to(tempfile.path)
            end

            cache = SchemaCache.load_from(tempfile.path)
            cache.connection = @connection

            assert_sql(/SELECT t.oid, t.typname, t.typelem/) do
              @connection.execute("CREATE TYPE account_status AS ENUM ('new', 'open', 'closed');")
              @connection.execute("ALTER TABLE accounts ADD status account_status NOT NULL DEFAULT 'new';")
              cache.dump_to(tempfile.path)
            end
          ensure
            @connection.execute("DELETE FROM accounts; ALTER TABLE accounts DROP COLUMN status;DROP TYPE IF EXISTS account_status;")
          end
        end
      end
    end
  end
end
