# frozen_string_literal: true

# :enddoc:

# Make double-sure the RAILS_ENV is not set to production,
# so fixtures aren't loaded into that environment
abort("Abort testing: Your Rails environment is running in production mode!") if Rails.env.production?

require "active_support/test_case"
require "action_controller"
require "action_controller/test_case"
require "action_dispatch/testing/integration"
require "rails/generators/test_case"

require "active_support/testing/autorun"

require "rails/testing/maintain_test_schema"

if defined?(ActiveRecord::Base)
  ActiveSupport.on_load(:active_support_test_case) do
    include ActiveRecord::TestDatabases
    include ActiveRecord::TestFixtures

    self.fixture_paths << "#{Rails.root}/test/fixtures/"
    self.file_fixture_path = "#{Rails.root}/test/fixtures/files"
  end

  ActiveSupport.on_load(:action_dispatch_integration_test) do
    self.fixture_paths += ActiveSupport::TestCase.fixture_paths
  end
else
  ActiveSupport.on_load(:active_support_test_case) do
    self.file_fixture_path = "#{Rails.root}/test/fixtures/files"
  end
end

ActiveSupport.on_load(:action_controller_test_case) do
  def before_setup
    @routes = Rails.application.routes
    super
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  def before_setup
    @routes = Rails.application.routes
    super
  end
end
