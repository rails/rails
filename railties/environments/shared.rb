RAILS_ROOT = File.expand_path(File.dirname(__FILE__) + "/../")
RAILS_ENV  = ENV['RAILS_ENV'] || 'development'

ADDITIONAL_LOAD_PATHS = [
  "app/models", 
  "app/controllers", 
  "app/helpers", 
  "app",
  "config", 
  "lib", 
  "vendor",
  "vendor/railties", 
  "vendor/railties/lib", 
  "vendor/activerecord/lib", 
  "vendor/actionpack/lib",
  "vendor/actionmailer/lib",
]

ADDITIONAL_LOAD_PATHS.unshift(Dir["#{RAILS_ROOT}/app/models/[a-z]*"].collect{ |dir| "app/models/#{File.basename(dir)}" })
ADDITIONAL_LOAD_PATHS.unshift("test/mocks/#{RAILS_ENV}")

ADDITIONAL_LOAD_PATHS.flatten.each { |dir| $: << "#{RAILS_ROOT}/#{dir}" }


require 'active_record'
require 'action_controller'
require 'action_mailer'

require 'yaml'

ActionController::Base.template_root = ActionMailer::Base.template_root = "#{RAILS_ROOT}/app/views/"
ActiveRecord::Base.configurations = YAML::load(File.open("#{RAILS_ROOT}/config/database.yml"))

ActionController::Base.require_or_load 'abstract_application'
ActionController::Base.require_or_load "environments/#{RAILS_ENV}"