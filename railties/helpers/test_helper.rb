require File.dirname(__FILE__) + "/../config/environments/test"

require 'test/unit'
require 'active_record/fixtures'
require 'action_controller/test_process'

def create_fixtures(*table_names)
  Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures", table_names)
end