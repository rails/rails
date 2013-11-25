require "cases/helper"

class MysqlConnectionTest < ActiveRecord::TestCase
  def setup
    super
    @subscriber = SQLSubscriber.new
    ActiveSupport::Notifications.subscribe('sql.active_record', @subscriber)
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscriber)
    super
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

  def test_mysql_set_session_variable
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.deep_merge({:variables => {:default_week_format => 3}}))
      session_mode = ActiveRecord::Base.connection.exec_query "SELECT @@SESSION.DEFAULT_WEEK_FORMAT"
      assert_equal 3, session_mode.rows.first.first.to_i
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

  def test_logs_non_utf8_queries
    iso_name = [0xE9].pack('C*').force_encoding(Encoding::ISO_8859_1)
    utf8_name = [0xC3, 0xA9].pack('C*').force_encoding(Encoding::UTF_8)
    sql = "DROP TABLE #{iso_name}"

    logged_error = nil
    @connection.logger.expects(:error).with { |message| logged_error = message }

    assert_raise(ActiveRecord::StatementInvalid) do
      @connection.execute sql
    end

    assert_equal Encoding::UTF_8, logged_error.encoding
    assert_includes logged_error, utf8_name

    assert_equal Encoding::ISO_8859_1, @subscriber.logged[0][0].encoding
    assert_includes @subscriber.logged[0][0], iso_name
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
