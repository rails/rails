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

Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"

class Test::Unit::TestCase
  # Turn these on to use transactional fixtures with table_name(:fixture_name) instantiation of fixtures
  # self.use_transactional_fixtures = true
  # self.use_instantiated_fixtures  = false

  def create_fixtures(*table_names)
    Fixtures.create_fixtures(File.dirname(__FILE__) + "/fixtures", table_names)
  end

  # Add more helper methods to be used by all tests here...
end