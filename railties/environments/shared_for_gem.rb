RAILS_ROOT = File.expand_path(File.dirname(__FILE__) + "/../")
RAILS_ENV  = ENV['RAILS_ENV'] || 'development'

ADDITIONAL_LOAD_PATHS = [ "app/models", "app/controllers", "app/helpers", "config", "lib", "vendor" ]
ADDITIONAL_LOAD_PATHS.unshift(Dir["#{RAILS_ROOT}/app/models/[a-z]*"].collect{ |dir| "app/models/#{File.basename(dir)}" })
ADDITIONAL_LOAD_PATHS.unshift("test/mocks/#{RAILS_ENV}")

ADDITIONAL_LOAD_PATHS.flatten.each { |dir| $:.unshift "#{RAILS_ROOT}/#{dir}" }

require 'rubygems'

require_gem 'activerecord'
require_gem 'actionpack'
require_gem 'actionmailer'
require_gem 'rails'

require 'yaml'

ActionController::Base.template_root = ActionMailer::Base.template_root = "#{RAILS_ROOT}/app/views/"
ActiveRecord::Base.configurations = YAML::load(File.open("#{RAILS_ROOT}/config/database.yml"))

ActionController::Base.require_or_load 'abstract_application'
ActionController::Base.require_or_load "environments/#{RAILS_ENV}"
