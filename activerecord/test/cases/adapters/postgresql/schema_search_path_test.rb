require "cases/helper"

module ActiveRecord
    class PostgresqlSchemaSearchPathTest < ActiveRecord::TestCase
        def test_schema_search_path_is_reset_after_rollback
          conn = ActiveRecord::Base.connection
          conn.schema_search_path = "public"
          conn.begin_db_transaction
          conn.rollback_db_transaction
          assert_equal "public", conn.schema_search_path
        end
    end
end