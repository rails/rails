require "active_support/testing/autorun"
require "action_system_test"

class ServerTest < ActiveSupport::TestCase
  test "initializing the server port" do
    server = ActionSystemTest::Server
    assert_includes Capybara.servers, :rails_puma
  end
end
