ADDITIONAL_LOAD_PATHS = [ "app/models", "app/controllers", "app/helpers", "config", "lib", "vendor" ]
ADDITIONAL_LOAD_PATHS.each { |dir| $:.unshift "#{File.dirname(__FILE__)}/../../#{dir}" }

require 'rubygems'

require_gem 'activerecord'
require_gem 'actionpack'
require_gem 'actionmailer'
require_gem 'rails'

require 'yaml'

ActionController::Base.template_root = ActionMailer::Base.template_root = File.dirname(__FILE__) + '/../../app/views/'

def database_configurations
  YAML::load(File.open(File.dirname(__FILE__) + "/../../config/database.yml"))
end