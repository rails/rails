require "cases/helper"
require "support/connection_helper"

module ActiveRecord
    class PostgresqlSchemaSearchPathTest < ActiveRecord::TestCase
        def setup
            @conn = ActiveRecord::Base.connection
        end

        def test_schema_search_path_cache_is_cleared_after_rollback
            @conn.execute("Set search_path to pg_catalog")

            assert_equal "pg_catalog", @conn.schema_search_path

            #Rollback transaction
            @conn.begin_db_transaction
            @conn.exec_rollback_db_transaction

            #after rollback, cache should be cleared and search_path should be cleared
            assert_nil @conn.instance_variable_get(:@schema_search_path)
        end

        def test_schema_search_path_cache_is_cleared_after_restart_rollback
            @conn.begin_db_transaction
            @conn.exec_restart_db_transaction

            assert_nil @conn.instance_variable_get(:@schema_search_path)
        end
    end
end