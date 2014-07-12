require 'abstract_unit'
require 'env_helpers'
require 'rails/commands/server'

class Rails::ServerTest < ActiveSupport::TestCase
  include EnvHelpers

  def test_environment_with_server_option
    args    = ["thin", "-e", "production"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal 'production', options[:environment]
    assert_equal 'thin', options[:server]
  end

  def test_environment_without_server_option
    args    = ["-e", "production"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal 'production', options[:environment]
    assert_nil options[:server]
  end

  def test_server_option_without_environment
    args    = ["thin"]
    options = Rails::Server::Options.new.parse!(args)
    assert_nil options[:environment]
    assert_equal 'thin', options[:server]
  end

  def test_environment_with_rails_env
    with_rack_env nil do
      with_rails_env 'production' do
        server = Rails::Server.new
        assert_equal 'production', server.options[:environment]
      end
    end
  end

  def test_environment_with_rack_env
    with_rails_env nil do
      with_rack_env 'production' do
        server = Rails::Server.new
        assert_equal 'production', server.options[:environment]
      end
    end
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

        with_rack_env 'development' do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal true, options[:log_stdout]
        end

        with_rack_env 'production' do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal false, options[:log_stdout]
        end

        with_rails_env 'development' do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal true, options[:log_stdout]
        end

        with_rails_env 'production' do
          args    = []
          options = Rails::Server::Options.new.parse!(args)
          assert_equal false, options[:log_stdout]
        end
      end
    end
  end
end
