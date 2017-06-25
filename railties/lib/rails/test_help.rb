# Make double-sure the RAILS_ENV is not set to production,
# so fixtures aren't loaded into that environment
abort("Abort testing: Your Rails environment is running in production mode!") if Rails.env.production?

require 'active_support/test_case'
require 'action_controller'
require 'action_controller/test_case'
require 'action_dispatch/testing/integration'
require 'rails/generators/test_case'

require 'active_support/testing/autorun'

if defined?(ActiveRecord::Base)
  ActiveRecord::Migration.maintain_test_schema!

  class ActiveSupport::TestCase
    include ActiveRecord::TestFixtures
    self.fixture_path = "#{Rails.root}/test/fixtures/"
    self.file_fixture_path = self.fixture_path + "files"
  end

  ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path

  def create_fixtures(*fixture_set_names, &block)
    FixtureSet.create_fixtures(ActiveSupport::TestCase.fixture_path, fixture_set_names, {}, &block)
  end
end

class ActionController::TestCase
  def before_setup # :nodoc:
    @routes = Rails.application.routes
    super
  end
end

class ActionDispatch::IntegrationTest
  def before_setup # :nodoc:
    @routes = Rails.application.routes
    super
  end
end
