require File.dirname(__FILE__) + "/../../vendor/railties/configs/load_path"

require 'active_record'
require 'action_controller'

require 'yaml'

ActionController::Base.template_root = File.dirname(__FILE__) + '/../../app/views/'

def database_configurations
  YAML::load(File.open(File.dirname(__FILE__) + "/../../config/database.yml"))
end