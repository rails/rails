require "cases/helper"
require 'models/developer'

module ActiveRecord
  module ConnectionAdapters
    class SQLite3Adapter
      class ExplainTest < ActiveRecord::TestCase
        fixtures :developers

        def test_explain_for_one_query
          explain = Developer.where(:id => 1).explain
          assert_match %(EXPLAIN for: SELECT "developers".* FROM "developers"  WHERE "developers"."id" = 1), explain
          assert_match(/(SEARCH )?TABLE developers USING (INTEGER )?PRIMARY KEY/, explain)
        end

        def test_explain_with_eager_loading
          explain = Developer.where(:id => 1).includes(:audit_logs).explain
          assert_match %(EXPLAIN for: SELECT "developers".* FROM "developers"  WHERE "developers"."id" = 1), explain
          assert_match(/(SEARCH )?TABLE developers USING (INTEGER )?PRIMARY KEY/, explain)
          assert_match %(EXPLAIN for: SELECT "audit_logs".* FROM "audit_logs"  WHERE "audit_logs"."developer_id" IN (1)), explain
          assert_match(/(SCAN )?TABLE audit_logs/, explain)
        end
      end
    end
  end
end
