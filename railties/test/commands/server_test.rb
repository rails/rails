require 'abstract_unit'
require 'rails/commands/server'

class Rails::ServerTest < ActiveSupport::TestCase

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
    rails = ENV['RAILS_ENV']
    ENV['RAILS_ENV'] = 'production'
    server = Rails::Server.new
    assert_equal 'production', server.options[:environment]
  ensure
    ENV['RAILS_ENV'] = rails
  end

  def test_environment_with_rack_env
    rack, rails = ENV['RACK_ENV'], ENV['RAILS_ENV']
    ENV['RAILS_ENV'] = nil
    ENV['RACK_ENV'] = 'production'
    server = Rails::Server.new
    assert_equal 'production', server.options[:environment]
  ensure
    ENV['RACK_ENV'] = rack
    ENV['RAILS_ENV'] = rails
  end
end
