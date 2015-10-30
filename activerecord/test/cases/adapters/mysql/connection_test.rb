require "cases/helper"
require 'support/connection_helper'
require 'support/ddl_helper'

class MysqlConnectionTest < ActiveRecord::MysqlTestCase
  include ConnectionHelper
  include DdlHelper

  class Klass < ActiveRecord::Base
  end

  def setup
    super
    @connection = ActiveRecord::Base.connection
  end

  def test_mysql_reconnect_attribute_after_connection_with_reconnect_true
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge({:reconnect => true}))
      assert ActiveRecord::Base.connection.raw_connection.reconnect
    end
  end

  unless ARTest.connection_config['arunit']['socket']
    def test_connect_with_url
      run_without_connection do
        ar_config = ARTest.connection_config['arunit']

        url = "mysql://#{ar_config["username"]}:#{ar_config["password"]}@localhost/#{ar_config["database"]}"
        Klass.establish_connection(url)
        assert_equal ar_config['database'], Klass.connection.current_database
      end
    end
  end

  def test_mysql_reconnect_attribute_after_connection_with_reconnect_false
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge({:reconnect => false}))
      assert !ActiveRecord::Base.connection.raw_connection.reconnect
    end
  end

  def test_no_automatic_reconnection_after_timeout
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    assert !@connection.active?

    # Repair all fixture connections so other tests won't break.
    @fixture_connections.each(&:verify!)
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

  def test_bind_value_substitute
    bind_param = @connection.substitute_at('foo')
    assert_equal Arel.sql('?'), bind_param.to_sql
  end

  def test_exec_no_binds
    with_example_table do
      result = @connection.exec_query('SELECT id, data FROM ex')
      assert_equal 0, result.rows.length
      assert_equal 2, result.columns.length
      assert_equal %w{ id data }, result.columns

      @connection.exec_query('INSERT INTO ex (id, data) VALUES (1, "foo")')

      # if there are no bind parameters, it will return a string (due to
      # the libmysql api)
      result = @connection.exec_query('SELECT id, data FROM ex')
      assert_equal 1, result.rows.length
      assert_equal 2, result.columns.length

      assert_equal [['1', 'foo']], result.rows
    end
  end

  def test_exec_with_binds
    with_example_table do
      @connection.exec_query('INSERT INTO ex (id, data) VALUES (1, "foo")')
      result = @connection.exec_query(
        'SELECT id, data FROM ex WHERE id = ?', nil, [ActiveRecord::Relation::QueryAttribute.new("id", 1, ActiveRecord::Type::Value.new)])

      assert_equal 1, result.rows.length
      assert_equal 2, result.columns.length

      assert_equal [[1, 'foo']], result.rows
    end
  end

  def test_exec_typecasts_bind_vals
    with_example_table do
      @connection.exec_query('INSERT INTO ex (id, data) VALUES (1, "foo")')
      bind = ActiveRecord::Relation::QueryAttribute.new("id", "1-fuu", ActiveRecord::Type::Integer.new)

      result = @connection.exec_query(
        'SELECT id, data FROM ex WHERE id = ?', nil, [bind])

      assert_equal 1, result.rows.length
      assert_equal 2, result.columns.length

      assert_equal [[1, 'foo']], result.rows
    end
  end

  def test_mysql_connection_collation_is_configured
    assert_equal 'utf8_unicode_ci', @connection.show_variable('collation_connection')
    assert_equal 'utf8_general_ci', ARUnit2Model.connection.show_variable('collation_connection')
  end

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

  def test_mysql_strict_mode_specified_default
    run_without_connection do |orig_connection|
      ActiveRecord::Base.establish_connection(orig_connection.merge({strict: :default}))
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

  def test_get_and_release_advisory_lock
    key = "test_key"

    got_lock = @connection.get_advisory_lock(key)
    assert got_lock, "get_advisory_lock should have returned true but it didn't"

    assert_equal test_lock_free(key), false,
      "expected the test advisory lock to be held but it wasn't"

    released_lock = @connection.release_advisory_lock(key)
    assert released_lock, "expected release_advisory_lock to return true but it didn't"

    assert test_lock_free(key), 'expected the test key to be available after releasing'
  end

  def test_release_non_existent_advisory_lock
    fake_key = "fake_key"
    released_non_existent_lock = @connection.release_advisory_lock(fake_key)
    assert_equal released_non_existent_lock, false,
      'expected release_advisory_lock to return false when there was no lock to release'
  end

  protected

  def test_lock_free(key)
    @connection.select_value("SELECT IS_FREE_LOCK('#{key}');") == '1'
  end

  private

  def with_example_table(&block)
    definition ||= <<-SQL
      `id` int auto_increment PRIMARY KEY,
      `data` varchar(255)
    SQL
    super(@connection, 'ex', definition, &block)
  end
end
