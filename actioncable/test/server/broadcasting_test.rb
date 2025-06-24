# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class BroadcastingTest < ActionCable::TestCase
  setup do
    @server = TestServer.new
    @broadcasting = "test_queue"
    @broadcaster = server.broadcaster_for(@broadcasting)
  end

  attr_reader :server, :broadcasting, :broadcaster

  test "fetching a broadcaster converts the broadcasting queue to a string" do
    assert_equal "test_queue", broadcaster.broadcasting
  end

  test "broadcast generates notification" do
    message = { body: "test message" }
    expected_payload = { broadcasting:, message:, coder: ActiveSupport::JSON }

    assert_notifications_count("broadcast.action_cable", 1) do
      assert_notification("broadcast.action_cable", expected_payload) do
        server.broadcast(broadcasting, message)
      end
    end
  end

  test "broadcaster from broadcaster_for generates notification" do
    message = { body: "test message" }
    expected_payload = { broadcasting:, message:, coder: ActiveSupport::JSON }

    assert_notifications_count("broadcast.action_cable", 1) do
      assert_notification("broadcast.action_cable", expected_payload) do
        broadcaster.broadcast(message)
      end
    end
  end
end
