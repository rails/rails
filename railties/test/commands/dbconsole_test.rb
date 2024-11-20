# frozen_string_literal: true

require "abstract_unit"
require "minitest/mock"
require "rails/command"
require "rails/commands/dbconsole/dbconsole_command"
require "active_record/database_configurations"
require "active_support/testing/method_call_assertions"
require "active_record/connection_adapters/sqlite3_adapter"

class Rails::DBConsoleTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  def setup
    Rails::DBConsole.const_set("APP_PATH", "rails/all")
  end

  def teardown
    Rails::DBConsole.send(:remove_const, "APP_PATH")
    %w[DATABASE_URL].each { |key| ENV.delete(key) }
  end

  def test_config_with_db_config_only
    config_sample = {
      "test" => {
        "adapter" => "sqlite3",
        "host" => "localhost",
        "port" => "9000",
        "database" => "foo_test",
        "user" => "foo",
        "password" => "bar",
        "pool" => "5",
        "timeout" => "3000"
      }
    }
    app_db_config(config_sample) do
      assert_equal config_sample["test"].symbolize_keys, Rails::DBConsole.new.db_config.configuration_hash
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
    ENV["DATABASE_URL"] = "postgresql://foo:bar@localhost:9000/foo_test?pool=5&timeout=3000"
    expected = {
      adapter:  "postgresql",
      host:     "localhost",
      port:     9000,
      database: "foo_test",
      username: "foo",
      password: "bar",
      pool:     "5",
      timeout:  "3000"
    }.sort

    app_db_config(nil) do
      assert_equal expected, Rails::DBConsole.new.db_config.configuration_hash.sort
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
      assert_equal host, Rails::DBConsole.new.db_config.configuration_hash[:host]
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

  def test_rails_env_is_development_when_environment_option_is_dev
    stub_available_environments([ "development", "test" ]) do
      assert_match("development", parse_arguments([ "-e", "dev" ])[:environment])
    end
  end

  def test_start
    assert_called_with(ActiveRecord::ConnectionAdapters::SQLite3Adapter, :exec, [/sqlite3/, /db\.sqlite3/]) do
      start(adapter: "sqlite3", database: "db.sqlite3")
    end
    assert_not aborted
  end

  def test_unknown_command_line_client
    start(adapter: "unknown", database: "db")
    assert aborted
    assert_match(/Database configuration specifies nonexistent 'unknown' adapter/, output)
  end

  def test_primary_is_automatically_picked_with_3_level_configuration
    sample_config = {
      "test" => {
        "primary" => {
          "adapter" => "postgresql"
        }
      }
    }

    app_db_config(sample_config) do
      assert_equal "postgresql", Rails::DBConsole.new.db_config.configuration_hash[:adapter]
    end
  end

  def test_specifying_a_custom_database_and_environment
    stub_available_environments(["development"]) do
      dbconsole = parse_arguments(["--db", "custom", "-e", "development"])

      assert_equal "development", dbconsole[:environment]
      assert_equal "custom", dbconsole.database
    end
  end

  def test_specifying_a_replica_database
    options = {
      database: "primary_replica",
    }

    sample_config = {
      "test" => {
        "primary" => { "adapter" => "sqlite3" },
        "primary_replica" => {
          "adapter" => "sqlite3",
          "replica" => true,
        }
      }
    }

    app_db_config(sample_config) do
      assert_equal "primary_replica", Rails::DBConsole.new(options).db_config.name
    end
  end

  def test_specifying_a_missing_database
    app_db_config({}) do
      e = assert_raises(ActiveRecord::AdapterNotSpecified) do
        Rails::Command.invoke(:dbconsole, ["--db", "i_do_not_exist"])
      end

      assert_includes e.message, "'i_do_not_exist' database is not configured for 'test'."
    end
  end

  def test_specifying_a_missing_environment
    app_db_config({}) do
      e = assert_raises(ActiveRecord::AdapterNotSpecified) do
        Rails::Command.invoke(:dbconsole)
      end

      assert_includes e.message, "No databases are configured for 'test'."
    end
  end

  def test_print_help_short
    stdout = capture(:stdout) do
      Rails::Command.invoke(:dbconsole, ["-h"])
    end
    assert_match %r"bin/rails dbconsole", stdout
  end

  def test_print_help_long
    stdout = capture(:stdout) do
      Rails::Command.invoke(:dbconsole, ["--help"])
    end
    assert_match %r"bin/rails dbconsole", stdout
  end

  attr_reader :aborted, :output
  private :aborted, :output

  private
    def app_db_config(results, &block)
      Rails.application.config.stub(:database_configuration, results || {}, &block)
    end

    attr_reader :dbconsole

    def start(config = {}, argv = [])
      @dbconsole = Rails::DBConsole.new(parse_arguments(argv))
      hash_config = nil
      @dbconsole.stub(:db_config, -> { hash_config ||= ActiveRecord::DatabaseConfigurations::HashConfig.new("test", "primary", config) }) do
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
      Rails::Command::DbconsoleCommand.new([], args).options
    end
end
