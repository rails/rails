require "cases/helper"
require 'models/topic'
require 'models/reply'

class MysqlStoredProcedureTest < ActiveRecord::MysqlTestCase
  fixtures :topics

  def setup
    @connection = ActiveRecord::Base.connection
    unless ActiveRecord::Base.connection.version >= '5.6.0' || Mysql.const_defined?(:CLIENT_MULTI_RESULTS)
      skip("no stored procedure support")
    end
  end

  # Test that MySQL allows multiple results for stored procedures
  #
  # In MySQL 5.6, CLIENT_MULTI_RESULTS is enabled by default.
  # http://dev.mysql.com/doc/refman/5.6/en/call.html
  def test_multi_results
    rows = @connection.select_rows('CALL ten();')
    assert_equal 10, rows[0][0].to_i, "ten() did not return 10 as expected: #{rows.inspect}"
    assert @connection.active?, "Bad connection use by 'MysqlAdapter.select_rows'"
  end

  def test_multi_results_from_find_by_sql
    topics = Topic.find_by_sql 'CALL topics(3);'
    assert_equal 3, topics.size
    assert @connection.active?, "Bad connection use by 'MysqlAdapter.select'"
  end
end
