# frozen_string_literal: true

require "test_helper"
require "concurrent"

require "active_support/core_ext/hash/indifferent_access"
require "pathname"

module CommonSubscriptionAdapterTest
  WAIT_WHEN_EXPECTING_EVENT = 3
  WAIT_WHEN_NOT_EXPECTING_EVENT = 0.2

  def setup
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.with_indifferent_access

    adapter_klass = server.config.pubsub_adapter

    @rx_adapter = adapter_klass.new(server)
    @tx_adapter = adapter_klass.new(server)
  end

  def teardown
    [@rx_adapter, @tx_adapter].uniq.compact.each(&:shutdown)
  end

  def subscribe_as_queue(channel, adapter = @rx_adapter)
    queue = Queue.new

    callback = -> data { queue << data }
    subscribed = Concurrent::Event.new
    adapter.subscribe(channel, callback, Proc.new { subscribed.set })
    subscribed.wait(WAIT_WHEN_EXPECTING_EVENT)
    assert_predicate subscribed, :set?

    yield queue

    sleep WAIT_WHEN_NOT_EXPECTING_EVENT
    assert_empty queue
  ensure
    if subscribed.set?
      adapter.unsubscribe(channel, callback)
      wait_for_pubsub_executor(adapter)
    end
  end

  def test_subscribe_and_unsubscribe
    subscribe_as_queue("channel") do |queue|
    end
  end

  def test_basic_broadcast
    subscribe_as_queue("channel") do |queue|
      @tx_adapter.broadcast("channel", "hello world")

      assert_equal "hello world", queue.pop
    end
  end

  def test_broadcast_after_unsubscribe
    keep_queue = nil
    subscribe_as_queue("channel") do |queue|
      keep_queue = queue

      @tx_adapter.broadcast("channel", "hello world")

      assert_equal "hello world", queue.pop
    end

    @tx_adapter.broadcast("channel", "hello void")

    sleep WAIT_WHEN_NOT_EXPECTING_EVENT
    assert_empty keep_queue
  end

  def test_multiple_broadcast
    subscribe_as_queue("channel") do |queue|
      @tx_adapter.broadcast("channel", "bananas")
      @tx_adapter.broadcast("channel", "apples")

      received = []
      2.times { received << queue.pop }
      assert_equal ["apples", "bananas"], received.sort
    end
  end

  def test_identical_subscriptions
    subscribe_as_queue("channel") do |queue|
      subscribe_as_queue("channel") do |queue_2|
        @tx_adapter.broadcast("channel", "hello")

        assert_equal "hello", queue_2.pop
      end

      assert_equal "hello", queue.pop
    end
  end

  def test_simultaneous_subscriptions
    subscribe_as_queue("channel") do |queue|
      subscribe_as_queue("other channel") do |queue_2|
        @tx_adapter.broadcast("channel", "apples")
        @tx_adapter.broadcast("other channel", "oranges")

        assert_equal "apples", queue.pop
        assert_equal "oranges", queue_2.pop
      end
    end
  end

  def test_channel_filtered_broadcast
    subscribe_as_queue("channel") do |queue|
      @tx_adapter.broadcast("other channel", "one")
      @tx_adapter.broadcast("channel", "two")

      assert_equal "two", queue.pop
    end
  end

  def test_long_identifiers
    channel_1 = "a" * 100 + "1"
    channel_2 = "a" * 100 + "2"
    subscribe_as_queue(channel_1) do |queue|
      subscribe_as_queue(channel_2) do |queue_2|
        @tx_adapter.broadcast(channel_1, "apples")
        @tx_adapter.broadcast(channel_2, "oranges")

        assert_equal "apples", queue.pop
        assert_equal "oranges", queue_2.pop
      end
    end
  end

  def wait_for_pubsub_executor(adapter)
    # We use a wrapper over ConcurrentRuby::ThreadPoolExecutor, so we need to dig deeper
    executor = adapter.instance_variable_get(:@executor).instance_variable_get(:@executor)
    wait_for_executor(executor)
  end
end
