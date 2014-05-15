# Activate the gem you are reporting the issue against.
gem 'rails', '4.0.0'

require 'rails'
require 'action_controller/railtie'

class TestApp < Rails::Application
  config.root = File.dirname(__FILE__)
  config.session_store :cookie_store, key: 'cookie_store_key'
  config.secret_token    = 'secret_token'
  config.secret_key_base = 'secret_key_base'

  config.logger = Logger.new($stdout)
  Rails.logger  = config.logger

  routes.draw do
    get '/' => 'test#index'
  end
end

class TestController < ActionController::Base
  include Rails.application.routes.url_helpers

  def index
    render text: 'Home'
  end
end

require 'minitest/autorun'
require 'rack/test'

# Ensure backward compatibility with Minitest 4
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

class BugTest < Minitest::Test
  include Rack::Test::Methods

  def test_returns_success
    get '/'
    assert last_response.ok?
  end

  private
    def app
      Rails.application
    end
end
