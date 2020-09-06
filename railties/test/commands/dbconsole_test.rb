# frozen_string_literal: true

require 'abstract_unit'
require 'minitest/mock'
require 'rails/command'
require 'rails/commands/dbconsole/dbconsole_command'
require 'active_record/database_configurations'

class Rails::DBConsoleTest < ActiveSupport::TestCase
  def setup
    Rails::DBConsole.const_set('APP_PATH', 'rails/all')
  end

  def teardown
    Rails::DBConsole.send(:remove_const, 'APP_PATH')
    %w[PGUSER PGHOST PGPORT PGPASSWORD DATABASE_URL].each { |key| ENV.delete(key) }
  end

  def test_config_with_db_config_only
    config_sample = {
      'test' => {
        'adapter' => 'sqlite3',
        'host' => 'localhost',
        'port' => '9000',
        'database' => 'foo_test',
        'user' => 'foo',
        'password' => 'bar',
        'pool' => '5',
        'timeout' => '3000'
      }
    }
    app_db_config(config_sample) do
      assert_equal config_sample['test'].symbolize_keys, Rails::DBConsole.new.db_config.configuration_hash
    end
  end

  def test_config_with_no_db_config
    app_db_config(nil) do
      assert_raise(ActiveRecord::AdapterNotSpecified) {
        Rails::DBConsole.new.db_config.configuration_hash
      }
    end
  end

  def test_config_with_database_url_only
    ENV['DATABASE_URL'] = 'postgresql://foo:bar@localhost:9000/foo_test?pool=5&timeout=3000'
    expected = {
      adapter:  'postgresql',
      host:     'localhost',
      port:     9000,
      database: 'foo_test',
      username: 'foo',
      password: 'bar',
      pool:     '5',
      timeout:  '3000'
    }.sort

    app_db_config(nil) do
      assert_equal expected, Rails::DBConsole.new.db_config.configuration_hash.sort
    end
  end

  def test_config_choose_database_url_if_exists
    host = 'database-url-host.com'
    ENV['DATABASE_URL'] = "postgresql://foo:bar@#{host}:9000/foo_test?pool=5&timeout=3000"
    sample_config = {
      'test' => {
        'adapter'  => 'postgresql',
        'host'     => "not-the-#{host}",
        'port'     => 9000,
        'database' => 'foo_test',
        'username' => 'foo',
        'password' => 'bar',
        'pool'     => '5',
        'timeout'  => '3000'
      }
    }
    app_db_config(sample_config) do
      assert_equal host, Rails::DBConsole.new.db_config.configuration_hash[:host]
    end
  end

  def test_env
    assert_equal 'test', Rails::DBConsole.new.environment

    ENV['RAILS_ENV'] = nil
    ENV['RACK_ENV'] = nil

    Rails.stub(:respond_to?, false) do
      assert_equal 'development', Rails::DBConsole.new.environment

      ENV['RACK_ENV'] = 'rack_env'
      assert_equal 'rack_env', Rails::DBConsole.new.environment

      ENV['RAILS_ENV'] = 'rails_env'
      assert_equal 'rails_env', Rails::DBConsole.new.environment
    end
  ensure
    ENV['RAILS_ENV'] = 'test'
    ENV['RACK_ENV'] = nil
  end

  def test_rails_env_is_development_when_environment_option_is_dev
    stub_available_environments([ 'development', 'test' ]) do
      assert_match('development', parse_arguments([ '-e', 'dev' ])[:environment])
    end
  end

  def test_mysql
    start(adapter: 'mysql2', database: 'db')
    assert_not aborted
    assert_equal [%w[mysql mysql5], 'db'], dbconsole.find_cmd_and_exec_args
  end

  def test_mysql_full
    start(adapter: 'mysql2', database: 'db', host: 'localhost', port: 1234, socket: 'socket', username: 'user', password: 'qwerty', encoding: 'UTF-8')
    assert_not aborted
    assert_equal [%w[mysql mysql5], '--host=localhost', '--port=1234', '--socket=socket', '--user=user', '--default-character-set=UTF-8', '-p', 'db'], dbconsole.find_cmd_and_exec_args
  end

  def test_mysql_include_password
    start({ adapter: 'mysql2', database: 'db', username: 'user', password: 'qwerty' }, ['-p'])
    assert_not aborted
    assert_equal [%w[mysql mysql5], '--user=user', '--password=qwerty', 'db'], dbconsole.find_cmd_and_exec_args
  end

  def test_postgresql
    start(adapter: 'postgresql', database: 'db')
    assert_not aborted
    assert_equal ['psql', 'db'], dbconsole.find_cmd_and_exec_args
  end

  def test_postgresql_full
    start(adapter: 'postgresql', database: 'db', username: 'user', password: 'q1w2e3', host: 'host', port: 5432)
    assert_not aborted
    assert_equal ['psql', 'db'], dbconsole.find_cmd_and_exec_args
    assert_equal 'user', ENV['PGUSER']
    assert_equal 'host', ENV['PGHOST']
    assert_equal '5432', ENV['PGPORT']
    assert_not_equal 'q1w2e3', ENV['PGPASSWORD']
  end

  def test_postgresql_include_password
    start({ adapter: 'postgresql', database: 'db', username: 'user', password: 'q1w2e3' }, ['-p'])
    assert_not aborted
    assert_equal ['psql', 'db'], dbconsole.find_cmd_and_exec_args
    assert_equal 'user', ENV['PGUSER']
    assert_equal 'q1w2e3', ENV['PGPASSWORD']
  end

  def test_sqlite3
    start(adapter: 'sqlite3', database: 'db.sqlite3')
    assert_not aborted
    assert_equal ['sqlite3', Rails.root.join('db.sqlite3').to_s], dbconsole.find_cmd_and_exec_args
  end

  def test_sqlite3_mode
    start({ adapter: 'sqlite3', database: 'db.sqlite3' }, ['--mode', 'html'])
    assert_not aborted
    assert_equal ['sqlite3', '-html', Rails.root.join('db.sqlite3').to_s], dbconsole.find_cmd_and_exec_args
  end

  def test_sqlite3_header
    start({ adapter: 'sqlite3', database: 'db.sqlite3' }, ['--header'])
    assert_equal ['sqlite3', '-header', Rails.root.join('db.sqlite3').to_s], dbconsole.find_cmd_and_exec_args
  end

  def test_sqlite3_db_absolute_path
    start(adapter: 'sqlite3', database: '/tmp/db.sqlite3')
    assert_not aborted
    assert_equal ['sqlite3', '/tmp/db.sqlite3'], dbconsole.find_cmd_and_exec_args
  end

  def test_sqlite3_db_without_defined_rails_root
    Rails.stub(:respond_to?, false) do
      start(adapter: 'sqlite3', database: 'config/db.sqlite3')
      assert_not aborted
      assert_equal ['sqlite3', Rails.root.join('../config/db.sqlite3').to_s], dbconsole.find_cmd_and_exec_args
    end
  end

  def test_oracle
    start(adapter: 'oracle', database: 'db', username: 'user', password: 'secret')
    assert_not aborted
    assert_equal ['sqlplus', 'user@db'], dbconsole.find_cmd_and_exec_args
  end

  def test_oracle_include_password
    start({ adapter: 'oracle', database: 'db', username: 'user', password: 'secret' }, ['-p'])
    assert_not aborted
    assert_equal ['sqlplus', 'user/secret@db'], dbconsole.find_cmd_and_exec_args
  end

  def test_sqlserver
    start(adapter: 'sqlserver', database: 'db', username: 'user', password: 'secret', host: 'localhost', port: 1433)
    assert_not aborted
    assert_equal ['sqsh', '-D', 'db', '-U', 'user', '-P', 'secret', '-S', 'localhost:1433'], dbconsole.find_cmd_and_exec_args
  end

  def test_unknown_command_line_client
    start(adapter: 'unknown', database: 'db')
    assert aborted
    assert_match(/Unknown command-line client for db/, output)
  end

  def test_primary_is_automatically_picked_with_3_level_configuration
    sample_config = {
      'test' => {
        'primary' => {
          'adapter' => 'postgresql'
        }
      }
    }

    app_db_config(sample_config) do
      assert_equal 'postgresql', Rails::DBConsole.new.db_config.configuration_hash[:adapter]
    end
  end

  def test_specifying_a_custom_database_and_environment
    stub_available_environments(['development']) do
      dbconsole = parse_arguments(['--db', 'custom', '-e', 'development'])

      assert_equal 'development', dbconsole[:environment]
      assert_equal 'custom', dbconsole.database
    end
  end

  def test_specifying_a_missing_database
    app_db_config({}) do
      e = assert_raises(ActiveRecord::AdapterNotSpecified) do
        Rails::Command.invoke(:dbconsole, ['--db', 'i_do_not_exist'])
      end

      assert_includes e.message, "'i_do_not_exist' database is not configured for 'test'."
    end
  end

  def test_specifying_a_missing_environment
    app_db_config({}) do
      e = assert_raises(ActiveRecord::AdapterNotSpecified) do
        Rails::Command.invoke(:dbconsole)
      end

      assert_includes e.message, "'primary' database is not configured for 'test'."
    end
  end

  def test_connection_options_is_deprecate
    command = Rails::Command::DbconsoleCommand.new([], ['-c', 'custom'])
    Rails::DBConsole.stub(:start, nil) do
      assert_deprecated('`connection` option is deprecated') do
        command.perform
      end
    end

    assert_equal 'custom', command.options['connection']
    assert_equal 'custom', command.options['database']
  end

  def test_print_help_short
    stdout = capture(:stdout) do
      Rails::Command.invoke(:dbconsole, ['-h'])
    end
    assert_match(/rails dbconsole \[options\]/, stdout)
  end

  def test_print_help_long
    stdout = capture(:stdout) do
      Rails::Command.invoke(:dbconsole, ['--help'])
    end
    assert_match(/rails dbconsole \[options\]/, stdout)
  end

  attr_reader :aborted, :output
  private :aborted, :output

  private
    def app_db_config(results)
      Rails.application.config.stub(:database_configuration, results || {}) do
        yield
      end
    end

    def make_dbconsole
      Class.new(Rails::DBConsole) do
        attr_reader :find_cmd_and_exec_args

        def find_cmd_and_exec(*args)
          @find_cmd_and_exec_args = args
        end
      end
    end

    attr_reader :dbconsole

    def start(config = {}, argv = [])
      hash_config = ActiveRecord::DatabaseConfigurations::HashConfig.new('test', 'primary', config)

      @dbconsole = make_dbconsole.new(parse_arguments(argv))
      @dbconsole.stub(:db_config, hash_config) do
        capture_abort { @dbconsole.start }
      end
    end

    def capture_abort
      @aborted = false
      @output = capture(:stderr) do
        yield
      rescue SystemExit
        @aborted = true
      end
    end

    def stub_available_environments(environments)
      Rails::Command::DbconsoleCommand.class_eval do
        alias_method :old_environments, :available_environments

        define_method :available_environments do
          environments
        end
      end

      yield
    ensure
      Rails::Command::DbconsoleCommand.class_eval do
        undef_method :available_environments
        alias_method :available_environments, :old_environments
        undef_method :old_environments
      end
    end

    def parse_arguments(args)
      Rails::Command::DbconsoleCommand.class_eval do
        alias_method :old_perform, :perform
        define_method(:perform) do
          extract_environment_option_from_argument

          options
        end
      end

      Rails::Command.invoke(:dbconsole, args)
    ensure
      Rails::Command::DbconsoleCommand.class_eval do
        undef_method :perform
        alias_method :perform, :old_perform
        undef_method :old_perform
      end
    end
end
