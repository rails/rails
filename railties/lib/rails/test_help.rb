# Make double-sure the RAILS_ENV is not set to production,
# so fixtures aren't loaded into that environment
abort("Abort testing: Your Rails environment is running in production mode!") if Rails.env.production?

require 'minitest/autorun'
require 'active_support/test_case'
require 'action_controller/test_case'
require 'action_dispatch/testing/integration'

# Config Rails backtrace in tests.
require 'rails/backtrace_cleaner'
MiniTest.backtrace_filter = Rails.backtrace_cleaner

# Enable turn if it is available
begin
  require 'turn'

  Turn.config do |c|
    c.natural = true
  end
rescue LoadError
end

if defined?(ActiveRecord::Base)
  class ActiveSupport::TestCase
    include ActiveRecord::TestFixtures
    self.fixture_path = "#{Rails.root}/test/fixtures/"
  end

  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path

  def create_fixtures(*fixture_set_names, &block)
    FixtureSet.create_fixtures(ActiveSupport::TestCase.fixture_path, fixture_set_names, {}, &block)
  end
end

class ActionController::TestCase
  setup do
    @routes = Rails.application.routes
  end
end

class ActionDispatch::IntegrationTest
  setup do
    @routes = Rails.application.routes
  end
end
