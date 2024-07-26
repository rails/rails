require File.dirname(__FILE__) + "/../config/environments/test"

require 'test/unit'
require 'active_record/fixtures'
require 'action_controller/test_process'

# Make rubygems available for testing if possible
begin require('rubygems');        rescue LoadError; end
begin require('dev-utils/debug'); rescue LoadError; end

def create_fixtures(*table_names)
  Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures", table_names)
end

Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"