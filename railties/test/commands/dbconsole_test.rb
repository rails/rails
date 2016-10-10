require "abstract_unit"
require "minitest/mock"
require "rails/command"
require "rails/commands/dbconsole/dbconsole_command"

class Rails::DBConsoleTest < ActiveSupport::TestCase
  def setup
    Rails::DBConsole.const_set("APP_PATH", "rails/all")
  end

  def teardown
    Rails::DBConsole.send(:remove_const, "APP_PATH")
    %w[PGUSER PGHOST PGPORT PGPASSWORD DATABASE_URL].each { |key| ENV.delete(key) }
  end

  def test_config_with_db_config_only
    config_sample = {
      "test"=> {
        "adapter"=> "sqlite3",
        "host"=> "localhost",
        "port"=> "9000",
        "database"=> "foo_test",
        "user"=> "foo",
        "password"=> "bar",
        "pool"=> "5",
        "timeout"=> "3000"
      }
    }
    app_db_config(config_sample) do
      assert_equal config_sample["test"], Rails::DBConsole.new.config
    end
  end

  def test_config_with_no_db_config
    app_db_config(nil) do
      assert_raise(ActiveRecord::AdapterNotSpecified) {
        Rails::DBConsole.new.config
      }
    end
  end

  def test_config_with_database_url_only
    ENV["DATABASE_URL"] = "postgresql://foo:bar@localhost:9000/foo_test?pool=5&timeout=3000"
    expected = {
      "adapter"  => "postgresql",
      "host"     => "localhost",
      "port"     => 9000,
      "database" => "foo_test",
      "username" => "foo",
      "password" => "bar",
      "pool"     => "5",
      "timeout"  => "3000"
    }.sort

    app_db_config(nil) do
      assert_equal expected, Rails::DBConsole.new.config.sort
    end
  end

  def test_config_choose_database_url_if_exists
    host = "database-url-host.com"
    ENV["DATABASE_URL"] = "postgresql://foo:bar@#{host}:9000/foo_test?pool=5&timeout=3000"
    sample_config = {
      "test" => {
        "adapter"  => "postgresql",
        "host"     => "not-the-#{host}",
        "port"     => 9000,
        "database" => "foo_test",
        "username" => "foo",
        "password" => "bar",
        "pool"     => "5",
        "timeout"  => "3000"
      }
    }
    app_db_config(sample_config) do
      assert_equal host, Rails::DBConsole.new.config["host"]
    end
  end

  def test_env
    assert_equal "test", Rails::DBConsole.new.environment

    ENV["RAILS_ENV"] = nil
    ENV["RACK_ENV"] = nil

    Rails.stub(:respond_to?, false) do
      assert_equal "development", Rails::DBConsole.new.environment

      ENV["RACK_ENV"] = "rack_env"
      assert_equal "rack_env", Rails::DBConsole.new.environment

      ENV["RAILS_ENV"] = "rails_env"
      assert_equal "rails_env", Rails::DBConsole.new.environment
    end
  ensure
    ENV["RAILS_ENV"] = "test"
    ENV["RACK_ENV"] = nil
  end

  def test_rails_env_is_development_when_argument_is_dev
    stub_available_environments([ "development", "test" ]) do
      assert_match("development", parse_arguments([ "dev" ])[:environment])
    end
  end

  def test_rails_env_is_dev_when_argument_is_dev_and_dev_env_is_present
    stub_available_environments([ "dev" ]) do
      assert_match("dev", parse_arguments([ "dev" ])[:environment])
    end
  end

  def test_mysql
    start(adapter: "mysql2", database: "db")
    assert !aborted
    assert_equal [%w[mysql mysql5], "db"], dbconsole.find_cmd_and_exec_args
  end

  def test_mysql_full
    start(adapter: "mysql2", database: "db", host: "locahost", port: 1234, socket: "socket", username: "user", password: "qwerty", encoding: "UTF-8")
    assert !aborted
    assert_equal [%w[mysql mysql5], "--host=locahost", "--port=1234", "--socket=socket", "--user=user", "--default-character-set=UTF-8", "-p", "db"], dbconsole.find_cmd_and_exec_args
  end

  def test_mysql_include_password
    start({ adapter: "mysql2", database: "db", username: "user", password: "qwerty" }, ["-p"])
    assert !aborted
    assert_equal [%w[mysql mysql5], "--user=user", "--password=qwerty", "db"], dbconsole.find_cmd_and_exec_args
  end

  def test_postgresql
    start(adapter: "postgresql", database: "db")
    assert !aborted
    assert_equal ["psql", "db"], dbconsole.find_cmd_and_exec_args
  end

  def test_postgresql_full
    start(adapter: "postgresql", database: "db", username: "user", password: "q1w2e3", host: "host", port: 5432)
    assert !aborted
    assert_equal ["psql", "db"], dbconsole.find_cmd_and_exec_args
    assert_equal "user", ENV["PGUSER"]
    assert_equal "host", ENV["PGHOST"]
    assert_equal "5432", ENV["PGPORT"]
    assert_not_equal "q1w2e3", ENV["PGPASSWORD"]
  end

  def test_postgresql_include_password
    start({ adapter: "postgresql", database: "db", username: "user", password: "q1w2e3" }, ["-p"])
    assert !aborted
    assert_equal ["psql", "db"], dbconsole.find_cmd_and_exec_args
    assert_equal "user", ENV["PGUSER"]
    assert_equal "q1w2e3", ENV["PGPASSWORD"]
  end

  def test_sqlite3
    start(adapter: "sqlite3", database: "db.sqlite3")
    assert !aborted
    assert_equal ["sqlite3", Rails.root.join("db.sqlite3").to_s], dbconsole.find_cmd_and_exec_args
  end

  def test_sqlite3_mode
    start({ adapter: "sqlite3", database: "db.sqlite3" }, ["--mode", "html"])
    assert !aborted
    assert_equal ["sqlite3", "-html", Rails.root.join("db.sqlite3").to_s], dbconsole.find_cmd_and_exec_args
  end

  def test_sqlite3_header
    start({ adapter: "sqlite3", database: "db.sqlite3" }, ["--header"])
    assert_equal ["sqlite3", "-header", Rails.root.join("db.sqlite3").to_s], dbconsole.find_cmd_and_exec_args
  end

  def test_sqlite3_db_absolute_path
    start(adapter: "sqlite3", database: "/tmp/db.sqlite3")
    assert !aborted
    assert_equal ["sqlite3", "/tmp/db.sqlite3"], dbconsole.find_cmd_and_exec_args
  end

  def test_sqlite3_db_without_defined_rails_root
    Rails.stub(:respond_to?, false) do
      start(adapter: "sqlite3", database: "config/db.sqlite3")
      assert !aborted
      assert_equal ["sqlite3", Rails.root.join("../config/db.sqlite3").to_s], dbconsole.find_cmd_and_exec_args
    end
  end

  def test_oracle
    start(adapter: "oracle", database: "db", username: "user", password: "secret")
    assert !aborted
    assert_equal ["sqlplus", "user@db"], dbconsole.find_cmd_and_exec_args
  end

  def test_oracle_include_password
    start({ adapter: "oracle", database: "db", username: "user", password: "secret" }, ["-p"])
    assert !aborted
    assert_equal ["sqlplus", "user/secret@db"], dbconsole.find_cmd_and_exec_args
  end

  def test_unknown_command_line_client
    start(adapter: "unknown", database: "db")
    assert aborted
    assert_match(/Unknown command-line client for db/, output)
  end

  def test_print_help_short
    stdout = capture(:stdout) do
      Rails::Command.invoke(:dbconsole, ["-h"])
    end
    assert_match(/bin\/rails dbconsole \[environment\]/, stdout)
  end

  def test_print_help_long
    stdout = capture(:stdout) do
      Rails::Command.invoke(:dbconsole, ["--help"])
    end
    assert_match(/bin\/rails dbconsole \[environment\]/, stdout)
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
      @dbconsole = make_dbconsole.new(parse_arguments(argv))
      @dbconsole.stub(:config, config.stringify_keys) do
        capture_abort { @dbconsole.start }
      end
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
