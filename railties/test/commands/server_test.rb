require "abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/server/server_command"

class Rails::ServerTest < ActiveSupport::TestCase
  include EnvHelpers

  def test_environment_with_server_option
    args    = ["thin", "-e", "production"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal "production", options[:environment]
    assert_equal "thin", options[:server]
  end

  def test_environment_without_server_option
    args    = ["-e", "production"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal "production", options[:environment]
    assert_nil options[:server]
  end

  def test_server_option_without_environment
    args    = ["thin"]
    options = Rails::Server::Options.new.parse!(args)
    assert_nil options[:environment]
    assert_equal "thin", options[:server]
  end

  def test_environment_with_rails_env
    with_rack_env nil do
      with_rails_env "production" do
        server = Rails::Server.new
        assert_equal "production", server.options[:environment]
      end
    end
  end

  def test_environment_with_rack_env
    with_rails_env nil do
      with_rack_env "production" do
        server = Rails::Server.new
        assert_equal "production", server.options[:environment]
      end
    end
  end

  def test_environment_with_port
    switch_env "PORT", "1234" do
      server = Rails::Server.new
      assert_equal 1234, server.options[:Port]
    end
  end

  def test_environment_with_host
    switch_env "HOST", "1.2.3.4" do
      server = Rails::Server.new
      assert_equal "1.2.3.4", server.options[:Host]
    end
  end

  def test_caching_without_option
    args = []
    options = Rails::Server::Options.new.parse!(args)
    merged_options = Rails::Server.new.default_options.merge(options)
    assert_equal nil, merged_options[:caching]
  end

  def test_caching_with_option
    args = ["--dev-caching"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal true, options[:caching]

    args = ["--no-dev-caching"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal false, options[:caching]
  end

  def test_log_stdout
    with_rack_env nil do
      with_rails_env nil do
        args    = []
        options = Rails::Server::Options.new.parse!(args)
        assert_equal true, options[:log_stdout]

        args    = ["-e", "development"]
        options = Rails::Server::Options.new.parse!(args)
        assert_equal true, options[:log_stdout]

        args    = ["-e", "production"]
        options = Rails::Server::Options.new.parse!(args)
        assert_equal false, options[:log_stdout]

        with_rack_env "development" do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal true, options[:log_stdout]
        end

        with_rack_env "production" do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal false, options[:log_stdout]
        end

        with_rails_env "development" do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal true, options[:log_stdout]
        end

        with_rails_env "production" do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal false, options[:log_stdout]
        end
      end
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
    args = ["-p", "4567"]
    ARGV.replace args

    options = Rails::Server::Options.new.parse! args
    server = Rails::Server.new options
    expected = "bin/rails server -p 4567"

    assert_equal expected, server.default_options[:restart_cmd]
  ensure
    ARGV.replace original_args
  end
end
