require "cases/helper"

class MysqlConnectionTest < ActiveRecord::TestCase
  def setup
    super
    @connection = ActiveRecord::Model.connection
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

  def test_mysql_strict_mode_disabled
    run_without_connection do |orig_connection|
      ActiveRecord::Model.establish_connection(orig_connection.merge({:strict => false}))
      result = ActiveRecord::Model.connection.exec_query "SELECT @@SESSION.sql_mode"
      assert_equal [['']], result.rows
    end
  end

  private

  def run_without_connection
    original_connection = ActiveRecord::Model.remove_connection
    begin
      yield original_connection
    ensure
      ActiveRecord::Model.establish_connection(original_connection)
    end
  end
end
