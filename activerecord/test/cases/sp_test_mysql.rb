require "cases/helper"
require 'models/topic'
require 'models/minimalistic'

class StoredProcedureTest < ActiveRecord::TestCase
  fixtures :topics

  # Test that MySQL allows multiple results for stored procedures
  if Mysql.const_defined?(:CLIENT_MULTI_RESULTS)
    def test_multi_results_from_find_by_sql
      topics = Topic.find_by_sql 'CALL topics();'
      assert_equal 1, topics.size
      assert ActiveRecord::Base.connection.active?, "Bad connection use by 'MysqlAdapter.select'"
    end
  end
end
