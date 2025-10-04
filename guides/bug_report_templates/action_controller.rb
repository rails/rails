# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"
end

require "action_controller/railtie"
require "minitest/autorun"
require "rack/test"

class TestApp < Rails::Application
  config.load_defaults Rails::VERSION::STRING.to_f
  config.root = __dir__
  config.eager_load = false
  config.hosts << "example.org"
  config.secret_key_base = "secret_key_base"

  config.logger = Logger.new($stdout)
end
Rails.application.initialize!

Rails.application.routes.draw do
  get "/", to: "test#index"
end

class TestController < ActionController::Base
  include Rails.application.routes.url_helpers

  def index
    render plain: "Home"
  end
end

class BugTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  def test_returns_success
    get "/"
    assert last_response.ok?
    assert_equal last_response.body, "Home"
  end

  private
    def app
      Rails.application
    end
end
