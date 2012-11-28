require "cases/helper"

class MysqlConnectionTest < ActiveRecord::TestCase
  def setup
    super
    @connection = ActiveRecord::Base.connection
    @connection.extend(LogIntercepter)
    @connection.intercepted = true
  end

  def teardown
    @connection.intercepted = false
    @connection.logged = []
  end

  def test_no_automatic_reconnection_after_timeout
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    assert !@connection.active?
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

  # TODO: Below is a straight up copy/paste from mysql/connection_test.rb
  # I'm not sure what the correct way is to share these tests between
  # adapters in minitest.
  def test_mysql_default_in_strict_mode
    result = @connection.exec_query "SELECT @@SESSION.sql_mode"
    assert_equal [["STRICT_ALL_TABLES"]], result.rows
  end

  def test_mysql_strict_mode_disabled_dont_override_global_sql_mode
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge({:strict => false}))
      global_sql_mode = ActiveRecord::Base.connection.exec_query "SELECT @@GLOBAL.sql_mode"
      session_sql_mode = ActiveRecord::Base.connection.exec_query "SELECT @@SESSION.sql_mode"
      assert_equal global_sql_mode.rows, session_sql_mode.rows
    end
  end

  def test_logs_name_structure_dump
    @connection.structure_dump
    assert_equal "SCHEMA", @connection.logged[0][1]
    assert_equal "SCHEMA", @connection.logged[2][1]
  end

  def test_logs_name_show_variable
    @connection.show_variable 'foo'
    assert_equal "SCHEMA", @connection.logged[0][1]
  end

  def test_logs_name_rename_column_sql
    @connection.execute "CREATE TABLE `bar_baz` (`foo` varchar(255))"
    @connection.logged = []
    @connection.send(:rename_column_sql, 'bar_baz', 'foo', 'foo2')
    assert_equal "SCHEMA", @connection.logged[0][1]
  ensure
    @connection.execute "DROP TABLE `bar_baz`"
  end

  private

  def run_without_connection
    original_connection = ActiveRecord::Base.remove_connection
    begin
      yield original_connection
    ensure
      ActiveRecord::Base.establish_connection(original_connection)
    end
  end
end
