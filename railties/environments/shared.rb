ADDITIONAL_LOAD_PATHS = [ 
  "app/models", 
  "app/controllers", 
  "app/helpers", 
  "config", 
  "lib", 
  "vendor",
  "vendor/railties", 
  "vendor/railties/lib", 
  "vendor/activerecord/lib", 
  "vendor/actionpack/lib",
  "vendor/actionmailer/lib"
]

ADDITIONAL_LOAD_PATHS.each { |dir| $:.unshift "#{File.dirname(__FILE__)}/../../#{dir}" }

require 'active_record'
require 'action_controller'
require 'action_mailer'

require 'yaml'

ActionController::Base.template_root = ActionMailer::Base.template_root = File.dirname(__FILE__) + '/../../app/views/'

def database_configurations
  YAML::load(File.open(File.dirname(__FILE__) + "/../../config/database.yml"))
end