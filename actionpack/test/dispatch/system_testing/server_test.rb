require "abstract_unit"
require "capybara/dsl"
require "action_dispatch/system_testing/server"

class ServerTest < ActiveSupport::TestCase
  setup do
    ActionDispatch::SystemTesting::Server.new.run
  end

  test "initializing the server port" do
    assert_includes Capybara.servers, :rails_puma
  end

  test "port is always included" do
    assert Capybara.always_include_port, "expected Capybara.always_include_port to be true"
  end
end
