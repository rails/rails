require_dependency 'application'

# Make double-sure the RAILS_ENV is set to test,
# so fixtures are loaded to the right database
silence_warnings { RAILS_ENV = "test" }

require 'test/unit'
require 'active_support/test_case'
require 'active_record/fixtures'
require 'action_controller/test_case'
require 'action_controller/test_process'
require 'action_controller/integration'
require 'action_mailer/test_case' if defined?(ActionMailer)

Test::Unit::TestCase.fixture_path = RAILS_ROOT + "/test/fixtures/"
ActionController::IntegrationTest.fixture_path = Test::Unit::TestCase.fixture_path

def create_fixtures(*table_names)
  Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names)
end
