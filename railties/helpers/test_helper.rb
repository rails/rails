ENV["RAILS_ENV"] = "test"

# Expand the path to environment so that Ruby does not load it multiple times
# File.expand_path can be removed if Ruby 1.9 is in use.
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'application'

require 'test/unit'
require 'active_record/fixtures'
require 'action_controller/test_process'
require 'action_web_service/test_invoke'
require 'breakpoint'

def create_fixtures(*table_names)
  Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures", table_names)
end

Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"
