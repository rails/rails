require "test_helper"

class BroadcastingTest < ActiveSupport::TestCase
  class TestServer
    include ActionCable::Server::Broadcasting
  end

  test "fetching a broadcaster converts the broadcasting queue to a string" do
    broadcasting = :test_queue
    server = TestServer.new
    broadcaster = server.broadcaster_for(broadcasting)

    assert_equal "test_queue", broadcaster.broadcasting
  end
end
