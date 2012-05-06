require 'abstract_unit'
require 'rails/commands/dbconsole'

class Rails::DBConsoleTest < ActiveSupport::TestCase
  def teardown
    %w[PGUSER PGHOST PGPORT PGPASSWORD'].each{|key| ENV.delete(key)}
  end

  def test_no_database_configured
    start [], false
    assert aborted
    assert_match /No database is configured for the environment '\w+'/, output
  end

  def test_mysql
    dbconsole.expects(:find_cmd_and_exec).with(%w[mysql mysql5], 'db')
    start [], {adapter: 'mysql', database: 'db'}
    assert !aborted
  end

  def test_mysql_full
    dbconsole.expects(:find_cmd_and_exec).with(%w[mysql mysql5], '--host=locahost', '--port=1234', '--socket=socket', '--user=user', '--default-character-set=UTF-8', '-p', 'db')
    start [], {adapter: 'mysql', database: 'db', host: 'locahost', port: 1234, socket: 'socket', username: 'user', password: 'qwerty', encoding: 'UTF-8'}
    assert !aborted
  end

  def test_mysql_include_password
    dbconsole.expects(:find_cmd_and_exec).with(%w[mysql mysql5], '--user=user', '--password=qwerty', 'db')
    start ['-p'], {adapter: 'mysql', database: 'db', username: 'user', password: 'qwerty'}
    assert !aborted
  end

  def test_postgresql
    dbconsole.expects(:find_cmd_and_exec).with('psql', 'db')
    start [], {adapter: 'postgresql', database: 'db'}
    assert !aborted
  end

  def test_postgresql_full
    dbconsole.expects(:find_cmd_and_exec).with('psql', 'db')
    start [], {adapter: 'postgresql', database: 'db', username: 'user', password: 'q1w2e3', host: 'host', port: 5432}
    assert !aborted
    assert_equal 'user', ENV['PGUSER']
    assert_equal 'host', ENV['PGHOST']
    assert_equal '5432', ENV['PGPORT']
    assert_not_equal 'q1w2e3', ENV['PGPASSWORD']
  end

  def test_postgresql_include_password
    dbconsole.expects(:find_cmd_and_exec).with('psql', 'db')
    start ['-p'], {adapter: 'postgresql', database: 'db', username: 'user', password: 'q1w2e3'}
    assert !aborted
    assert_equal 'user', ENV['PGUSER']
    assert_equal 'q1w2e3', ENV['PGPASSWORD']
  end

  def test_sqlite
    dbconsole.expects(:find_cmd_and_exec).with('sqlite', 'db')
    start [], {adapter: 'sqlite', database: 'db'}
    assert !aborted
  end

  def test_sqlite3
    dbconsole.expects(:find_cmd_and_exec).with('sqlite3', 'db')
    start [], {adapter: 'sqlite3', database: 'db'}
    assert !aborted
  end

  def test_sqlite3_mode
    dbconsole.expects(:find_cmd_and_exec).with('sqlite3', '-html', 'db')
    start ['--mode', 'html'], {adapter: 'sqlite3', database: 'db'}
    assert !aborted
  end

  def test_sqlite3_header
    dbconsole.expects(:find_cmd_and_exec).with('sqlite3', '-header', 'db')
    start ['--header'], {adapter: 'sqlite3', database: 'db'}
    assert !aborted
  end

  def test_oracle
    dbconsole.expects(:find_cmd_and_exec).with('sqlplus', 'user@db')
    start [], {adapter: 'oracle', database: 'db', username: 'user', password: 'secret'}
    assert !aborted
  end

  def test_oracle_include_password
    dbconsole.expects(:find_cmd_and_exec).with('sqlplus', 'user/secret@db')
    start ['-p'], {adapter: 'oracle', database: 'db', username: 'user', password: 'secret'}
    assert !aborted
  end

  def test_unknown_command_line_client
    start [], {adapter: 'unknown', database: 'db'}
    assert aborted
    assert_match /Unknown command-line client for db/, output
  end

  private
  attr_reader :aborted, :output

  def dbconsole
    @dbconsole ||= Rails::DBConsole.new(app)
  end

  def start(argv = [], database_configuration = {})
    dbconsole.stubs(arguments: argv)
    app.config.stubs(database_configuration: {
      Rails.env => database_configuration ? database_configuration.stringify_keys : database_configuration
    })

    @aborted = false
    @output = capture(:stderr) do 
      begin
        dbconsole.start
      rescue SystemExit
        @aborted = true
      end
    end
  end

  def app
    @app ||= begin
      config = mock("config")
      stub("app", config: config)
    end
  end
end
