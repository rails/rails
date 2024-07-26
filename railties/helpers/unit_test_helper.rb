require File.dirname(__FILE__) + '/../vendor/railties/load_path'

require 'test/unit'
require 'logger'
require 'yaml'

require 'active_record'
require 'active_record/fixtures'

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/../log/test.log")

db_conf = YAML::load(File.open(File.dirname(__FILE__) + "/../config/database.yml"))
ActiveRecord::Base.establish_connection(db_conf["test"])

def create_fixtures(table_name)
  Fixtures.new(ActiveRecord::Base.connection, table_name, File.dirname(__FILE__) + "/fixtures/#{table_name}")
end