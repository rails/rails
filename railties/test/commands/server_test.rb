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
    with_rails_env 'production' do
      server = Rails::Server.new
      assert_equal 'production', server.options[:environment]
    end
  end

  def test_environment_with_rack_env
    with_rack_env 'production' do
      server = Rails::Server.new
      assert_equal 'production', server.options[:environment]
    end
  end
end
