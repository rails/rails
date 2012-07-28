# Make double-sure the RAILS_ENV is not set to production,
# so fixtures aren't loaded into that environment
abort("Abort testing: Your Rails environment is running in production mode!") if Rails.env.production?

require 'test/unit'
require 'active_support/test_case'
require 'action_controller/test_case'
require 'action_dispatch/testing/integration'

if defined?(Test::Unit::Util::BacktraceFilter) && ENV['BACKTRACE'].nil?
  require 'rails/backtrace_cleaner'
  Test::Unit::Util::BacktraceFilter.module_eval { include Rails::BacktraceFilterForTestUnit }
end

if defined?(MiniTest)
  # Enable turn if it is available
  begin
    require 'turn'

    Turn.config do |c|
      c.natural = true
    end
  rescue LoadError
  end
end

if defined?(ActiveRecord::Base)
  require 'active_record/test_case'

  class ActiveSupport::TestCase
    include ActiveRecord::TestFixtures
    self.fixture_path = "#{Rails.root}/test/fixtures/"

    setup do
      ActiveRecord::IdentityMap.clear
    end
  end

  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path

  def create_fixtures(*table_names, &block)
    Fixtures.create_fixtures(ActiveSupport::TestCase.fixture_path, table_names, {}, &block)
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
