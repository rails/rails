require "cases/helper"
require 'support/connection_helper'

class MysqlConnectionTest < ActiveRecord::TestCase
  include ConnectionHelper

  fixtures :comments

  def setup
    super
    @subscriber = SQLSubscriber.new
    @subscription = ActiveSupport::Notifications.subscribe('sql.active_record', @subscriber)
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscription)
    super
  end

  def test_bad_connection
    assert_raise ActiveRecord::NoDatabaseError do
      configuration = ActiveRecord::Base.configurations['arunit'].merge(database: 'inexistent_activerecord_unittest')
      connection = ActiveRecord::Base.mysql2_connection(configuration)
      connection.exec_query('drop table if exists ex')
    end
  end

  def test_truncate
    rows = ActiveRecord::Base.connection.exec_query("select count(*) from comments")
    count = rows.first.values.first
    assert_operator count, :>, 0

    ActiveRecord::Base.connection.truncate("comments")
    rows = ActiveRecord::Base.connection.exec_query("select count(*) from comments")
    count = rows.first.values.first
    assert_equal 0, count
  end

  def test_no_automatic_reconnection_after_timeout
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    assert !@connection.active?

    # Repair all fixture connections so other tests won't break.
    @fixture_connections.each do |c|
      c.verify!
    end
  end

  def test_successful_reconnection_after_timeout_with_manual_reconnect
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    @connection.reconnect!
    assert @connection.active?
  end

  def test_successful_reconnection_after_timeout_with_verify
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    @connection.verify!
    assert @connection.active?
  end

  def test_execute_after_disconnect
    @connection.disconnect!
    error = assert_raise(ActiveRecord::StatementInvalid) do
      @connection.execute("SELECT 1")
    end
    assert_equal Mysql2::Error, error.original_exception.class
  end

  def test_quote_after_disconnect
    @connection.disconnect!
    assert_raise(Mysql2::Error) do
      @connection.quote("string")
    end
  end

  def test_active_after_disconnect
    @connection.disconnect!
    assert_equal false, @connection.active?
  end

  def test_wait_timeout_as_string
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge(wait_timeout: "60"))
      result = ActiveRecord::Base.connection.select_value("SELECT @@SESSION.wait_timeout")
      assert_equal 60, result
    end
  end

  def test_wait_timeout_as_url
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge("url" => "mysql2:///?wait_timeout=60"))
      result = ActiveRecord::Base.connection.select_value("SELECT @@SESSION.wait_timeout")
      assert_equal 60, result
    end
  end

  def test_mysql_connection_collation_is_configured
    assert_equal 'utf8_unicode_ci', @connection.show_variable('collation_connection')
    assert_equal 'utf8_general_ci', ARUnit2Model.connection.show_variable('collation_connection')
  end

  # TODO: Below is a straight up copy/paste from mysql/connection_test.rb
  # I'm not sure what the correct way is to share these tests between
  # adapters in minitest.
  def test_mysql_default_in_strict_mode
    result = @connection.exec_query "SELECT @@SESSION.sql_mode"
    assert_equal [["STRICT_ALL_TABLES"]], result.rows
  end

  def test_mysql_strict_mode_disabled
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge({:strict => false}))
      result = ActiveRecord::Base.connection.exec_query "SELECT @@SESSION.sql_mode"
      assert_equal [['']], result.rows
    end
  end

  def test_mysql_set_session_variable
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.deep_merge({:variables => {:default_week_format => 3}}))
      session_mode = ActiveRecord::Base.connection.exec_query "SELECT @@SESSION.DEFAULT_WEEK_FORMAT"
      assert_equal 3, session_mode.rows.first.first.to_i
    end
  end

  def test_mysql_sql_mode_variable_overrides_strict_mode
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.deep_merge(variables: { 'sql_mode' => 'ansi' }))
      result = ActiveRecord::Base.connection.exec_query 'SELECT @@SESSION.sql_mode'
      assert_not_equal [['STRICT_ALL_TABLES']], result.rows
    end
  end

  def test_mysql_set_session_variable_to_default
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.deep_merge({:variables => {:default_week_format => :default}}))
      global_mode = ActiveRecord::Base.connection.exec_query "SELECT @@GLOBAL.DEFAULT_WEEK_FORMAT"
      session_mode = ActiveRecord::Base.connection.exec_query "SELECT @@SESSION.DEFAULT_WEEK_FORMAT"
      assert_equal global_mode.rows, session_mode.rows
    end
  end

  def test_logs_name_show_variable
    @connection.show_variable 'foo'
    assert_equal "SCHEMA", @subscriber.logged[0][1]
  end

  def test_logs_name_rename_column_sql
    @connection.execute "CREATE TABLE `bar_baz` (`foo` varchar(255))"
    @subscriber.logged.clear
    @connection.send(:rename_column_sql, 'bar_baz', 'foo', 'foo2')
    assert_equal "SCHEMA", @subscriber.logged[0][1]
  ensure
    @connection.execute "DROP TABLE `bar_baz`"
  end

  if mysql_56?
    def test_quote_time_usec
      assert_equal "'1970-01-01 00:00:00.000000'", @connection.quote(Time.at(0))
      assert_equal "'1970-01-01 00:00:00.000000'", @connection.quote(Time.at(0).to_datetime)
    end
  end
end
