# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class BroadcastingTest < ActiveSupport::TestCase
  test "fetching a broadcaster converts the broadcasting queue to a string" do
    broadcasting = :test_queue
    server = TestServer.new
    broadcaster = server.broadcaster_for(broadcasting)

    assert_equal "test_queue", broadcaster.broadcasting
  end

  test "broadcast generates notification" do
    begin
      server = TestServer.new

      events = []
      ActiveSupport::Notifications.subscribe "broadcast.action_cable" do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      broadcasting = "test_queue"
      message = { body: "test message" }
      server.broadcast(broadcasting, message)

      assert_equal 1, events.length
      assert_equal "broadcast.action_cable", events[0].name
      assert_equal broadcasting, events[0].payload[:broadcasting]
      assert_equal message, events[0].payload[:message]
      assert_equal ActiveSupport::JSON, events[0].payload[:coder]
    ensure
      ActiveSupport::Notifications.unsubscribe "broadcast.action_cable"
    end
  end

  test "broadcaster from broadcaster_for generates notification" do
    begin
      server = TestServer.new

      events = []
      ActiveSupport::Notifications.subscribe "broadcast.action_cable" do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      broadcasting = "test_queue"
      message = { body: "test message" }

      broadcaster = server.broadcaster_for(broadcasting)
      broadcaster.broadcast(message)

      assert_equal 1, events.length
      assert_equal "broadcast.action_cable", events[0].name
      assert_equal broadcasting, events[0].payload[:broadcasting]
      assert_equal message, events[0].payload[:message]
      assert_equal ActiveSupport::JSON, events[0].payload[:coder]
    ensure
      ActiveSupport::Notifications.unsubscribe "broadcast.action_cable"
    end
  end
end
