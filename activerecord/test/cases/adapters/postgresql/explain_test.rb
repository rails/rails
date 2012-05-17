require "cases/helper"
require 'models/developer'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class ExplainTest < ActiveRecord::TestCase
        fixtures :developers

        def test_explain_for_one_query
          explain = Developer.where(:id => 1).explain
          assert_match %(EXPLAIN for: SELECT "developers".* FROM "developers"  WHERE "developers"."id" = 1), explain
          assert_match %(QUERY PLAN), explain
          assert_match %(Index Scan using developers_pkey on developers), explain
        end

        def test_explain_with_eager_loading
          explain = Developer.where(:id => 1).includes(:audit_logs).explain
          assert_match %(QUERY PLAN), explain
          assert_match %(EXPLAIN for: SELECT "developers".* FROM "developers"  WHERE "developers"."id" = 1), explain
          assert_match %(Index Scan using developers_pkey on developers), explain
          assert_match %(EXPLAIN for: SELECT "audit_logs".* FROM "audit_logs"  WHERE "audit_logs"."developer_id" IN (1)), explain
          assert_match %(Seq Scan on audit_logs), explain
        end

        def test_dont_explain_for_set_search_path
          queries = Thread.current[:available_queries_for_explain] = []
          ActiveRecord::Base.connection.schema_search_path = "public"
          assert queries.empty?
        end

      end
    end
  end
end
