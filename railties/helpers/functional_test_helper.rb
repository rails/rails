require File.dirname(__FILE__) + '/../vendor/railties/load_path'

require 'test/unit'
require 'logger'
require 'yaml'

require 'active_record'
require 'active_record/fixtures'

require 'action_controller'
require 'action_controller/test_process'

ActiveRecord::Base.logger = ActionController::Base.logger = Logger.new(File.dirname(__FILE__) + "/../log/test.log")

ActionController::Base.template_root = File.dirname(__FILE__) + '/../app/views/'

db_conf = YAML::load(File.open(File.dirname(__FILE__) + "/../config/database.yml"))
ActiveRecord::Base.establish_connection(db_conf["test"])

def create_fixtures(table_name)
  Fixtures.new(ActiveRecord::Base.connection, table_name, File.dirname(__FILE__) + "/fixtures/#{table_name}")
end