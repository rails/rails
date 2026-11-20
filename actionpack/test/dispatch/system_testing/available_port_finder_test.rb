# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/system_testing/available_port_finder"

class AvailablePortFinderTest < ActiveSupport::TestCase
  test "find returns a port available on the given host" do
    host = "127.0.0.1"
    port = ActionDispatch::SystemTesting::AvailablePortFinder.new(host).find
    assert_kind_of Integer, port

    # Ensure TCP connection is really available.
    server = TCPServer.new(host, port)
    assert_equal port, server.addr[1]
  ensure
    server&.close
  end
end
