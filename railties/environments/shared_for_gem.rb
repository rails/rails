RAILS_ROOT = File.expand_path(File.dirname(__FILE__) + "/../")
RAILS_ENV  = ENV['RAILS_ENV'] || 'development'


# Mocks first.
ADDITIONAL_LOAD_PATHS = ["#{RAILS_ROOT}/test/mocks/#{RAILS_ENV}"]

# Then model subdirectories.
ADDITIONAL_LOAD_PATHS.concat(Dir["#{RAILS_ROOT}/app/models/[a-z]*"])

# Followed by the standard includes.
ADDITIONAL_LOAD_PATHS.concat %w(
  app/models
  app/controllers
  app/helpers
  config
  lib
  vendor
).map { |dir| "#{RAILS_ROOT}/#{dir}" }

# Prepend to $LOAD_PATH
ADDITIONAL_LOAD_PATHS.reverse.each do |dir|
  $:.unshift(dir) if File.directory?(dir)
end


# Require Rails gems.
require 'rubygems'
require_gem 'activerecord'
require_gem 'actionpack'
require_gem 'actionmailer'
require_gem 'rails'


# Environment-specific configuration.
require 'yaml'
ActiveRecord::Base.configurations = YAML::load(File.open("#{RAILS_ROOT}/config/database.yml"))
ActionController::Base.require_or_load 'abstract_application'
ActionController::Base.require_or_load "environments/#{RAILS_ENV}"

# Configure defaults if the included environment did not.
RAILS_DEFAULT_LOGGER = Logger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}.log")
[ActiveRecord::Base, ActionController::Base, ActionMailer::Base].each do |klass|
  klass.logger ||= RAILS_DEFAULT_LOGGER
end
[ActionController::Base, ActionMailer::Base].each do |klass|
  klass.template_root ||= "#{RAILS_ROOT}/app/views/"
end


# Include your app's configuration here:
