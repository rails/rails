require "active_support/testing/autorun"
require "action_system_test"

class ServerTest < ActiveSupport::TestCase
  test "initializing the server port" do
    server = ActionSystemTest::Server.new(21800)
    assert_equal 21800, server.instance_variable_get(:@port)
  end
end
