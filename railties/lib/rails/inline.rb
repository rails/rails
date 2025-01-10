# frozen_string_literal: true

module Rails
  # Inline allows running a \Rails application in a single
  # script. Use +rails_app+ to initialize the application and
  # call +rails+ to run a \Rails command.
  #
  #   require "bundler/inline"
  #
  #   gemfile(true) do
  #     source "https://rubygems.org"
  #     gem 'rails'
  #   end
  #
  #   require "rails/inline"
  #
  #   rails_app do |config|
  #     config.root = __dir__
  #   end
  #
  #   rails :console
  #
  class Inline < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.hosts << "example.org"
    config.secret_key_base = "secret_key_base"
    config.logger = Logger.new($stdout)
  end
end

def rails_app
  yield(Rails.application.config)
  Rails.application.initialize!
end

def rails(command, args = [], **config)
  require "rails/command"
  Rails::Command.invoke command, args, **config
end
