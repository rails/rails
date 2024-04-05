# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails"
  # If you want to test against edge Rails replace the previous line with this:
  # gem "rails", github: "rails/rails", branch: "main"
end

require "action_controller/railtie"

class TestApp < Rails::Application
  config.root = __dir__
  config.hosts << "example.org"
  config.secret_key_base = "secret_key_base"

  config.logger = Logger.new($stdout)
  Rails.logger  = config.logger

  routes.draw do
    get "/" => "test#index"
  end
end

class TestController < ActionController::Base
  include Rails.application.routes.url_helpers

  def index
    render plain: "Home"
  end
end

require "minitest/autorun"

Rails.application.routes.draw do
  get "/test" => "test#index"
end

class TestControllerTest < ActionController::TestCase
  setup do
    @routes = Rails.application.routes
  end

  def test_returns_success
    get :index
    assert_response :success
  end

  private
    def app
      Rails.application
    end
end
