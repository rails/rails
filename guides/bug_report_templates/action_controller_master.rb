# frozen_string_literal: true

begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "rails", github: "rails/rails", branch: "5-2-stable"
end

require "action_controller/railtie"

class TestApp < Rails::Application
  config.root = __dir__
  secrets.secret_key_base = "secret_key_base"

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
require "rack/test"

class BugTest < Minitest::Test
  include Rack::Test::Methods

  def test_returns_success
    get "/"
    assert last_response.ok?
  end

  private
    def app
      Rails.application
    end
end
