# frozen_string_literal: true

# Make double-sure the RAILS_ENV is not set to production,
# so fixtures aren't loaded into that environment
abort("Abort testing: Your Rails environment is running in production mode!") if Rails.env.production?

require "active_support/test_case"
require "action_controller"
require "action_controller/test_case"
require "action_dispatch/testing/integration"
require "rails/generators/test_case"

require "active_support/testing/autorun"

if defined?(ActiveRecord::Base)
  begin
    ActiveRecord::Migration.maintain_test_schema!
  rescue ActiveRecord::PendingMigrationError => e
    puts e.to_s.strip
    exit 1
  end

  ActiveSupport.on_load(:active_support_test_case) do
    include ActiveRecord::TestDatabases
    include ActiveRecord::TestFixtures

    self.fixtures_paths = ["#{Rails.root}/test/fixtures/"]
    self.file_fixture_path = fixtures_paths.first + "files"
  end

  ActiveSupport.on_load(:action_dispatch_integration_test) do
    self.fixtures_paths = ActiveSupport::TestCase.fixtures_paths
  end
end

# :enddoc:

ActiveSupport.on_load(:action_controller_test_case) do
  def before_setup # :nodoc:
    @routes = Rails.application.routes
    super
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  def before_setup # :nodoc:
    @routes = Rails.application.routes
    super
  end
end
