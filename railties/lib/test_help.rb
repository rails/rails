require_dependency 'application'

# Make double-sure the RAILS_ENV is set to test,
# so fixtures are loaded to the right database
silence_warnings { RAILS_ENV = "test" }

require 'action_controller/integration'
require 'action_mailer/test_case' if defined?(ActionMailer)

require 'active_record/fixtures'
class ActiveSupport::TestCase
  include ActiveRecord::TestFixtures
end

ActiveSupport::TestCase.fixture_path = "#{RAILS_ROOT}/test/fixtures/"
ActionController::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path

def create_fixtures(*table_names)
  Fixtures.create_fixtures(ActiveSupport::TestCase.fixture_path, table_names)
end

begin
  require_library_or_gem 'ruby-debug'
  Debugger.start
  Debugger.settings[:autoeval] = true if Debugger.respond_to?(:settings)
rescue LoadError
  # ruby-debug wasn't available so neither can the debugging be
end
