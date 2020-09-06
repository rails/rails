# frozen_string_literal: true

require 'cases/helper'
require 'models/topic'
require 'models/reply'

class Mysql2StoredProcedureTest < ActiveRecord::Mysql2TestCase
  fixtures :topics

  def setup
    @connection = ActiveRecord::Base.connection
    unless ActiveRecord::Base.connection.database_version >= '5.6.0'
      skip('no stored procedure support')
    end
  end

  # Test that MySQL allows multiple results for stored procedures
  #
  # In MySQL 5.6, CLIENT_MULTI_RESULTS is enabled by default.
  # https://dev.mysql.com/doc/refman/en/call.html
  def test_multi_results
    rows = @connection.select_rows('CALL ten();')
    assert_equal 10, rows[0][0].to_i, "ten() did not return 10 as expected: #{rows.inspect}"
    assert @connection.active?, "Bad connection use by 'Mysql2Adapter.select_rows'"
  end

  def test_multi_results_from_select_one
    row = @connection.select_one('CALL topics(1);')
    assert_equal 'David', row['author_name']
    assert @connection.active?, "Bad connection use by 'Mysql2Adapter.select_one'"
  end

  def test_multi_results_from_find_by_sql
    topics = Topic.find_by_sql 'CALL topics(3);'
    assert_equal 3, topics.size
    assert @connection.active?, "Bad connection use by 'Mysql2Adapter.select'"
  end
end
