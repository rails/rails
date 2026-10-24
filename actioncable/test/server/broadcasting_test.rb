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

  class RecordingAdapter < SuccessAdapter
    attr_reader :calls

    def initialize(...)
      super
      @calls = []
    end

    def broadcast(channel, payload)
      @calls << [:broadcast, channel, payload]
    end

    def broadcast_batch(broadcasts)
      @calls << [:broadcast_batch, broadcasts]
    end
  end

  test "broadcasts made in batch_broadcasts reach the adapter together, in order, when the block ends" do
    server = TestServer.new(subscription_adapter: RecordingAdapter)

    server.batch_broadcasts do
      server.broadcast("room_1", { body: "one" })
      server.broadcaster_for("room_2").broadcast({ body: "two" })
      server.broadcast("room_1", "three", coder: nil)
      assert_empty server.pubsub.calls
    end

    assert_equal [[:broadcast_batch, [["room_1", '{"body":"one"}'], ["room_2", '{"body":"two"}'], ["room_1", "three"]]]], server.pubsub.calls
  end

  test "a batch inside another joins it and is sent by the outermost block" do
    server = TestServer.new(subscription_adapter: RecordingAdapter)

    server.batch_broadcasts do
      server.broadcast("room_1", "one", coder: nil)
      server.batch_broadcasts { server.broadcast("room_2", "two", coder: nil) }
      assert_empty server.pubsub.calls
    end

    assert_equal [[:broadcast_batch, [["room_1", "one"], ["room_2", "two"]]]], server.pubsub.calls
  end

  test "a batch is sent when its block raises" do
    server = TestServer.new(subscription_adapter: RecordingAdapter)

    assert_raises(RuntimeError) do
      server.batch_broadcasts do
        server.broadcast("room_1", "one", coder: nil)
        raise "boom"
      end
    end

    assert_equal [[:broadcast_batch, [["room_1", "one"]]]], server.pubsub.calls
  end

  test "broadcasts outside a batch, before or after one, are sent one at a time" do
    server = TestServer.new(subscription_adapter: RecordingAdapter)

    server.broadcast("room_1", "before", coder: nil)
    server.batch_broadcasts { }
    server.broadcast("room_1", "after", coder: nil)

    assert_equal [[:broadcast, "room_1", "before"], [:broadcast, "room_1", "after"]], server.pubsub.calls
  end

  test "a batch belongs to its thread" do
    server = TestServer.new(subscription_adapter: RecordingAdapter)
    batching, done = Queue.new, Queue.new

    server.batch_broadcasts do
      other = Thread.new do
        server.broadcast("room_2", "elsewhere", coder: nil)
        server.batch_broadcasts do
          server.broadcast("room_3", "its own", coder: nil)
          batching << true
          done.pop
        end
      end

      assert batching.pop(timeout: 5)
      server.broadcast("room_1", "here", coder: nil)
      assert_equal [[:broadcast, "room_2", "elsewhere"]], server.pubsub.calls
      done << true
      other.join
    end

    assert_equal [[:broadcast, "room_2", "elsewhere"], [:broadcast_batch, [["room_3", "its own"]]], [:broadcast_batch, [["room_1", "here"]]]], server.pubsub.calls
  end

  test "a batch isn't joined by a thread that shares the execution state, like a live streaming one" do
    server = TestServer.new(subscription_adapter: RecordingAdapter)

    server.batch_broadcasts do
      context = ActiveSupport::IsolatedExecutionState.context
      Thread.new do
        ActiveSupport::IsolatedExecutionState.share_with(context) do
          server.broadcast("room_2", "elsewhere", coder: nil)
          server.batch_broadcasts { server.broadcast("room_3", "its own", coder: nil) }
        end
      end.join
      server.broadcast("room_1", "here", coder: nil)
      assert_equal [[:broadcast, "room_2", "elsewhere"], [:broadcast_batch, [["room_3", "its own"]]]], server.pubsub.calls
    end

    assert_equal [:broadcast_batch, [["room_1", "here"]]], server.pubsub.calls.last
  end

  test "a batch belongs to its server" do
    server = TestServer.new(subscription_adapter: RecordingAdapter)
    other_server = TestServer.new(subscription_adapter: RecordingAdapter)

    server.batch_broadcasts do
      other_server.broadcast("room_2", "elsewhere", coder: nil)
      server.broadcast("room_1", "here", coder: nil)
      assert_equal [[:broadcast, "room_2", "elsewhere"]], other_server.pubsub.calls
    end

    assert_equal [[:broadcast, "room_2", "elsewhere"]], other_server.pubsub.calls
    assert_equal [[:broadcast_batch, [["room_1", "here"]]]], server.pubsub.calls
  end

  test "batch_broadcasts returns the value of its block" do
    server = TestServer.new(subscription_adapter: RecordingAdapter)

    assert_equal :done, server.batch_broadcasts { :done }
    assert_equal :done, server.batch_broadcasts { server.batch_broadcasts { :done } }
  end

  test "broadcasts in a batch generate their notifications" do
    server = TestServer.new(subscription_adapter: RecordingAdapter)
    message = { body: "test message" }

    assert_notifications_count("broadcast.action_cable", 2) do
      assert_notification("broadcast.action_cable", { broadcasting:, message:, coder: ActiveSupport::JSON }) do
        server.batch_broadcasts do
          server.broadcast(broadcasting, message)
          server.broadcast(broadcasting, message)
        end
      end
    end
  end
end
