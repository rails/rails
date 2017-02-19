require "abstract_unit"
require "capybara/dsl"
require "action_dispatch/system_testing/server"

class ServerTest < ActiveSupport::TestCase
  test "initializing the server port" do
    server = ActionDispatch::SystemTesting::Server.new.run
    assert_includes Capybara.servers, :rails_puma
  end
end
