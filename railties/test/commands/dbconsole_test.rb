require 'abstract_unit'
require 'rails/commands/dbconsole'

class Rails::DBConsoleTest < ActiveSupport::TestCase
  def teardown
    %w[PGUSER PGHOST PGPORT PGPASSWORD].each{|key| ENV.delete(key)}
  end

  def test_config
    Rails::DBConsole.const_set(:APP_PATH, "erb")

    app_config({})
    capture_abort { Rails::DBConsole.new.config }
    assert aborted
    assert_match(/No database is configured for the environment '\w+'/, output)

    app_config(test: "with_init")
    assert_equal Rails::DBConsole.new.config, "with_init"

    app_db_file("test:\n  without_init")
    assert_equal Rails::DBConsole.new.config, "without_init"

    app_db_file("test:\n  <%= Rails.something_app_specific %>")
    assert_equal Rails::DBConsole.new.config, "with_init"

    app_db_file("test:\n\ninvalid")
    assert_equal Rails::DBConsole.new.config, "with_init"
  end

  def test_env
    assert_equal Rails::DBConsole.new.environment, "test"

    ENV['RAILS_ENV'] = nil
    ENV['RACK_ENV'] = nil

    Rails.stubs(:respond_to?).with(:env).returns(false)
    assert_equal Rails::DBConsole.new.environment, "development"

    ENV['RACK_ENV'] = "rack_env"
    assert_equal Rails::DBConsole.new.environment, "rack_env"

    ENV['RAILS_ENV'] = "rails_env"
    assert_equal Rails::DBConsole.new.environment, "rails_env"
  ensure
    ENV['RAILS_ENV'] = "test"
  end

  def test_rails_env_is_development_when_argument_is_dev
    Rails::DBConsole.stubs(:available_environments).returns(['development', 'test'])
    options = Rails::DBConsole.new.send(:parse_arguments, ['dev'])
    assert_match('development', options[:environment])
  end

  def test_rails_env_is_dev_when_argument_is_dev_and_dev_env_is_present
    Rails::DBConsole.stubs(:available_environments).returns(['dev'])
    options = Rails::DBConsole.new.send(:parse_arguments, ['dev'])
    assert_match('dev', options[:environment])
  end

  def test_mysql
    dbconsole.expects(:find_cmd_and_exec).with(%w[mysql mysql5], 'db')
    start(adapter: 'mysql', database: 'db')
    assert !aborted
  end

  def test_mysql_full
    dbconsole.expects(:find_cmd_and_exec).with(%w[mysql mysql5], '--host=locahost', '--port=1234', '--socket=socket', '--user=user', '--default-character-set=UTF-8', '-p', 'db')
    start(adapter: 'mysql', database: 'db', host: 'locahost', port: 1234, socket: 'socket', username: 'user', password: 'qwerty', encoding: 'UTF-8')
    assert !aborted
  end

  def test_mysql_include_password
    dbconsole.expects(:find_cmd_and_exec).with(%w[mysql mysql5], '--user=user', '--password=qwerty', 'db')
    start({adapter: 'mysql', database: 'db', username: 'user', password: 'qwerty'}, ['-p'])
    assert !aborted
  end

  def test_postgresql
    dbconsole.expects(:find_cmd_and_exec).with('psql', 'db')
    start(adapter: 'postgresql', database: 'db')
    assert !aborted
  end

  def test_postgresql_full
    dbconsole.expects(:find_cmd_and_exec).with('psql', 'db')
    start(adapter: 'postgresql', database: 'db', username: 'user', password: 'q1w2e3', host: 'host', port: 5432)
    assert !aborted
    assert_equal 'user', ENV['PGUSER']
    assert_equal 'host', ENV['PGHOST']
    assert_equal '5432', ENV['PGPORT']
    assert_not_equal 'q1w2e3', ENV['PGPASSWORD']
  end

  def test_postgresql_include_password
    dbconsole.expects(:find_cmd_and_exec).with('psql', 'db')
    start({adapter: 'postgresql', database: 'db', username: 'user', password: 'q1w2e3'}, ['-p'])
    assert !aborted
    assert_equal 'user', ENV['PGUSER']
    assert_equal 'q1w2e3', ENV['PGPASSWORD']
  end

  def test_sqlite
    dbconsole.expects(:find_cmd_and_exec).with('sqlite', 'db')
    start(adapter: 'sqlite', database: 'db')
    assert !aborted
  end

  def test_sqlite3
    dbconsole.expects(:find_cmd_and_exec).with('sqlite3', Rails.root.join('db.sqlite3').to_s)
    start(adapter: 'sqlite3', database: 'db.sqlite3')
    assert !aborted
  end

  def test_sqlite3_mode
    dbconsole.expects(:find_cmd_and_exec).with('sqlite3', '-html', Rails.root.join('db.sqlite3').to_s)
    start({adapter: 'sqlite3', database: 'db.sqlite3'}, ['--mode', 'html'])
    assert !aborted
  end

  def test_sqlite3_header
    dbconsole.expects(:find_cmd_and_exec).with('sqlite3', '-header', Rails.root.join('db.sqlite3').to_s)
    start({adapter: 'sqlite3', database: 'db.sqlite3'}, ['--header'])
  end

  def test_sqlite3_db_absolute_path
    dbconsole.expects(:find_cmd_and_exec).with('sqlite3', '/tmp/db.sqlite3')
    start(adapter: 'sqlite3', database: '/tmp/db.sqlite3')
    assert !aborted
  end

  def test_sqlite3_db_without_defined_rails_root
    Rails.stubs(:respond_to?)
    Rails.expects(:respond_to?).with(:root).once.returns(false)
    dbconsole.expects(:find_cmd_and_exec).with('sqlite3', Rails.root.join('../config/db.sqlite3').to_s)
    start(adapter: 'sqlite3', database: 'config/db.sqlite3')
    assert !aborted
  end

  def test_oracle
    dbconsole.expects(:find_cmd_and_exec).with('sqlplus', 'user@db')
    start(adapter: 'oracle', database: 'db', username: 'user', password: 'secret')
    assert !aborted
  end

  def test_oracle_include_password
    dbconsole.expects(:find_cmd_and_exec).with('sqlplus', 'user/secret@db')
    start({adapter: 'oracle', database: 'db', username: 'user', password: 'secret'}, ['-p'])
    assert !aborted
  end

  def test_unknown_command_line_client
    start(adapter: 'unknown', database: 'db')
    assert aborted
    assert_match(/Unknown command-line client for db/, output)
  end

  def test_print_help_short
    stdout = capture(:stdout) do
      start({}, ['-h'])
    end
    assert aborted
    assert_equal '', output
    assert_match(/Usage:.*dbconsole/, stdout)
  end

  def test_print_help_long
    stdout = capture(:stdout) do
      start({}, ['--help'])
    end
    assert aborted
    assert_equal '', output
    assert_match(/Usage:.*dbconsole/, stdout)
  end

  private
  attr_reader :aborted, :output

  def dbconsole
    @dbconsole ||= Rails::DBConsole.new(nil)
  end

  def start(config = {}, argv = [])
    dbconsole.stubs(config: config.stringify_keys, arguments: argv)
    capture_abort { dbconsole.start }
  end

  def capture_abort
    @aborted = false
    @output = capture(:stderr) do
      begin
        yield
      rescue SystemExit
        @aborted = true
      end
    end
  end

  def app_db_file(result)
    IO.stubs(:read).with("config/database.yml").returns(result)
  end

  def app_config(result)
    Rails.application.config.stubs(:database_configuration).returns(result.stringify_keys)
  end
end
