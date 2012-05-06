require 'abstract_unit'
require 'rails/commands/server'

class Rails::ServerTest < ActiveSupport::TestCase

  def test_environment_with_server_option
    args    = ["thin", "RAILS_ENV=production"]
    options = Rails::Server::Options.new.parse!(args)
    assert_equal 'production', options[:environment]
    assert_equal 'thin', options[:server]
  end

  def test_environment_without_server_option
    args    = ["RAILS_ENV=production"]
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
end
