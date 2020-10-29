# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/server/server_command"

class Rails::Command::ServerCommandTest < ActiveSupport::TestCase
  include EnvHelpers

  def test_environment_with_server_option
    args = ["-u", "thin", "-e", "production"]
    options = parse_arguments(args)
    assert_equal "production", options[:environment]
    assert_equal "thin", options[:server]
  end

  def test_environment_without_server_option
    args = ["-e", "production"]
    options = parse_arguments(args)
    assert_equal "production", options[:environment]
    assert_nil options[:server]
  end

  def test_environment_option_is_properly_expanded
    args = ["-e", "prod"]
    options = parse_arguments(args)
    assert_equal "production", options[:environment]
  end

  def test_explicit_using_option
    args = ["-u", "thin"]
    options = parse_arguments(args)
    assert_equal "thin", options[:server]
  end

  def test_using_server_mistype
    assert_match(/Could not find server "tin". Maybe you meant "thin"?/, run_command("--using", "tin"))
  end

  def test_using_server_mistype_without_suggestion
    output = run_command("--using", "t")
    assert_match(/Could not find server "t"/, output)
    assert_no_match(/Maybe you meant/, output)
  end

  def test_using_known_server_that_isnt_in_the_gemfile
    assert_match(/Could not load server "unicorn". Maybe you need to the add it to the Gemfile/, run_command("-u", "unicorn"))
  end

  def test_daemon_with_option
    args = ["-d"]
    options = parse_arguments(args)
    assert_equal true, options[:daemonize]
  end

  def test_daemon_without_option
    args = []
    options = parse_arguments(args)
    assert_equal false, options[:daemonize]
  end

  def test_server_option_without_environment
    args = ["-u", "thin"]
    with_rack_env nil do
      with_rails_env nil do
        options = parse_arguments(args)
        assert_equal "development",  options[:environment]
        assert_equal "thin", options[:server]
      end
    end
  end

  def test_environment_with_rails_env
    with_rack_env nil do
      with_rails_env "production" do
        options = parse_arguments
        assert_equal "production", options[:environment]
      end
    end
  end

  def test_environment_with_rack_env
    with_rails_env nil do
      with_rack_env "production" do
        options = parse_arguments
        assert_equal "production", options[:environment]
      end
    end
  end

  def test_environment_with_port
    switch_env "PORT", "1234" do
      options = parse_arguments
      assert_equal 1234, options[:Port]
    end
  end

  def test_environment_with_host
    switch_env "HOST", "1.2.3.4" do
      assert_deprecated do
        options = parse_arguments
        assert_equal "1.2.3.4", options[:Host]
      end
    end
  end

  def test_environment_with_binding
    switch_env "BINDING", "1.2.3.4" do
      options = parse_arguments
      assert_equal "1.2.3.4", options[:Host]
    end
  end

  def test_environment_with_pidfile
    switch_env "PIDFILE", "/tmp/rails.pid" do
      options = parse_arguments
      assert_equal "/tmp/rails.pid", options[:pid]
    end
  end

  def test_caching_without_option
    args = []
    options = parse_arguments(args)
    assert_nil options[:caching]
  end

  def test_caching_with_option
    args = ["--dev-caching"]
    options = parse_arguments(args)
    assert_equal true, options[:caching]

    args = ["--no-dev-caching"]
    options = parse_arguments(args)
    assert_equal false, options[:caching]
  end

  def test_early_hints_with_option
    args = ["--early-hints"]
    options = parse_arguments(args)
    assert_equal true, options[:early_hints]
  end

  def test_early_hints_is_nil_by_default
    args = []
    options = parse_arguments(args)
    assert_nil options[:early_hints]
  end

  def test_log_stdout
    with_rack_env nil do
      with_rails_env nil do
        args    = []
        options = parse_arguments(args)
        assert_equal true, options[:log_stdout]

        args    = ["-e", "development"]
        options = parse_arguments(args)
        assert_equal true, options[:log_stdout]

        args    = ["-e", "development", "-d"]
        options = parse_arguments(args)
        assert_equal false, options[:log_stdout]

        args    = ["-e", "production"]
        options = parse_arguments(args)
        assert_equal false, options[:log_stdout]

        args    = ["-e", "development", "--no-log-to-stdout"]
        options = parse_arguments(args)
        assert_equal false, options[:log_stdout]

        args    = ["-e", "production", "--log-to-stdout"]
        options = parse_arguments(args)
        assert_equal true, options[:log_stdout]

        with_rack_env "development" do
          args    = []
          options = parse_arguments(args)
          assert_equal true, options[:log_stdout]
        end

        with_rack_env "production" do
          args    = []
          options = parse_arguments(args)
          assert_equal false, options[:log_stdout]
        end

        with_rails_env "development" do
          args    = []
          options = parse_arguments(args)
          assert_equal true, options[:log_stdout]
        end

        with_rails_env "production" do
          args    = []
          options = parse_arguments(args)
          assert_equal false, options[:log_stdout]
        end
      end
    end
  end

  def test_host
    with_rails_env "development" do
      options = parse_arguments([])
      assert_equal "localhost", options[:Host]
    end

    with_rails_env "production" do
      options = parse_arguments([])
      assert_equal "0.0.0.0", options[:Host]
    end

    with_rails_env "development" do
      args = ["-b", "127.0.0.1"]
      options = parse_arguments(args)
      assert_equal "127.0.0.1", options[:Host]
    end
  end

  def test_argument_precedence_over_environment_variable
    switch_env "PORT", "1234" do
      args = ["-p", "5678"]
      options = parse_arguments(args)
      assert_equal 5678, options[:Port]
    end

    switch_env "PORT", "1234" do
      args = ["-p", "3000"]
      options = parse_arguments(args)
      assert_equal 3000, options[:Port]
    end

    switch_env "BINDING", "1.2.3.4" do
      args = ["-b", "127.0.0.1"]
      options = parse_arguments(args)
      assert_equal "127.0.0.1", options[:Host]
    end

    switch_env "PIDFILE", "/tmp/rails.pid" do
      args = ["-P", "/somewhere/else.pid"]
      options = parse_arguments(args)
      assert_equal "/somewhere/else.pid", options[:pid]
    end
  end

  def test_records_user_supplied_options
    server_options = parse_arguments(["-p", "3001"])
    assert_equal [:Port], server_options[:user_supplied_options]

    server_options = parse_arguments(["--port", "3001"])
    assert_equal [:Port], server_options[:user_supplied_options]

    server_options = parse_arguments(["-p3001", "-C", "--binding", "127.0.0.1"])
    assert_equal [:Port, :Host, :caching], server_options[:user_supplied_options]

    server_options = parse_arguments(["--port=3001"])
    assert_equal [:Port], server_options[:user_supplied_options]

    switch_env "BINDING", "1.2.3.4" do
      server_options = parse_arguments
      assert_equal [:Host], server_options[:user_supplied_options]
    end

    switch_env "PORT", "3001" do
      server_options = parse_arguments
      assert_equal [:Port], server_options[:user_supplied_options]
    end

    switch_env "PIDFILE", "/tmp/server.pid" do
      server_options = parse_arguments
      assert_equal [:pid], server_options[:user_supplied_options]
    end
  end

  def test_default_options
    server = Rails::Server.new
    old_default_options = server.default_options

    Dir.chdir("..") do
      assert_equal old_default_options, server.default_options
    end
  end

  def test_restart_command_contains_customized_options
    original_args = ARGV.dup
    args = %w(-p 4567 -b 127.0.0.1 -c dummy_config.ru -d -e test -P tmp/server.pid -C)
    ARGV.replace args

    expected = "bin/rails server -p 4567 -b 127.0.0.1 -c dummy_config.ru -d -e test -P tmp/server.pid -C --restart"

    assert_equal expected, parse_arguments(args)[:restart_cmd]
  ensure
    ARGV.replace original_args
  end

  def test_served_url
    args = %w(-u webrick -b 127.0.0.1 -p 4567)
    server = Rails::Server.new(parse_arguments(args))
    assert_equal "http://127.0.0.1:4567", server.served_url
  end

  private
    def run_command(*args)
      build_app
      rails "server", *args
    ensure
      teardown_app
    end

    def parse_arguments(args = [])
      command = Rails::Command::ServerCommand.new([], args)
      command.send(:extract_environment_option_from_argument)
      command.server_options
    end
end
