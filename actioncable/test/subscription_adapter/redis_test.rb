# frozen_string_literal: true

require "test_helper"
require_relative "common"
require_relative "channel_prefix"

class RedisAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest
  include ChannelPrefixTest

  def cable_config
    { adapter: "redis", driver: "ruby" }.tap do |x|
      if host = ENV["REDIS_URL"]
        x[:url] = host
      end
    end
  end

  def test_resubscribe_after_removing_the_last_channel
    subscribe_as_queue("channel") do |queue|
      @tx_adapter.broadcast("channel", "hello world")

      assert_equal "hello world", queue.pop
    end

    # The block above unsubscribed from the only channel, driving the Redis
    # subscription count to zero. The listener must stay alive so a brand-new
    # subscription on the same adapter still receives broadcasts.
    subscribe_as_queue("channel") do |queue|
      @tx_adapter.broadcast("channel", "hallo welt")

      assert_equal "hallo welt", queue.pop
    end
  end

  def test_listener_thread_is_restarted_after_it_dies
    # A dedicated rx adapter that gives up reconnecting immediately, so a dropped
    # pubsub connection kills the listener thread (exhausted retries) instead of
    # recovering it. The sentinel only prevents the count-to-zero death; this
    # exercises ensure_listener_running reviving a thread that died otherwise.
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.merge(reconnect_attempts: 0).with_indifferent_access
    rx_adapter = server.config.pubsub_adapter.new(server)

    before_queue = Queue.new
    subscription_confirmed = Concurrent::Event.new
    rx_adapter.subscribe("channel", ->(data) { before_queue << data }, -> { subscription_confirmed.set })
    assert subscription_confirmed.wait(WAIT_WHEN_EXPECTING_EVENT)

    @tx_adapter.broadcast("channel", "before")
    assert_equal "before", before_queue.pop

    listener = rx_adapter.send(:listener)
    original_listener_thread = listener.instance_variable_get(:@thread)
    assert original_listener_thread.alive?

    drop_pubsub_connections
    wait_for(message: "the listener thread did not die after the connection drop") do
      !original_listener_thread.alive?
    end

    # Subscribing to a *new* channel goes through add_channel (a re-subscribe to
    # an existing channel would not), which must restart the dead listener.
    after_queue = Queue.new
    resubscription_confirmed = Concurrent::Event.new
    rx_adapter.subscribe("other channel", ->(data) { after_queue << data }, -> { resubscription_confirmed.set })
    assert resubscription_confirmed.wait(WAIT_WHEN_EXPECTING_EVENT)

    restarted_listener_thread = listener.instance_variable_get(:@thread)
    assert_not_same original_listener_thread, restarted_listener_thread
    assert restarted_listener_thread.alive?

    @tx_adapter.broadcast("other channel", "after")
    assert_equal "after", after_queue.pop
  ensure
    rx_adapter&.shutdown
  end

  def test_reconnections
    subscribe_as_queue("channel") do |queue|
      subscribe_as_queue("other channel") do |queue_2|
        @tx_adapter.broadcast("channel", "hello world")

        assert_equal "hello world", queue.pop

        drop_pubsub_connections
        wait_pubsub_connection(redis_conn, "channel")

        @tx_adapter.broadcast("channel", "hallo welt")

        assert_equal "hallo welt", queue.pop

        drop_pubsub_connections
        wait_pubsub_connection(redis_conn, "channel")
        wait_pubsub_connection(redis_conn, "other channel")

        @tx_adapter.broadcast("channel", "hola mundo")
        @tx_adapter.broadcast("other channel", "other message")

        assert_equal "hola mundo", queue.pop
        assert_equal "other message", queue_2.pop
      end
    end
  end

  private
    def redis_conn
      @redis_conn ||= ::RedisClient.config(**cable_config.except(:adapter)).new_client
    end

    def drop_pubsub_connections
      # Emulate connection failure by dropping all connections
      redis_conn.call("client", "kill", "type", "pubsub")
    end

    def wait_pubsub_connection(redis_conn, channel, timeout: 5)
      wait = timeout
      loop do
        break if redis_conn.call("pubsub", "numsub", channel).last > 0

        sleep 0.1
        wait -= 0.1

        raise "Timed out to subscribe to #{channel}" if wait <= 0
      end
    end
end

class RedisAdapterTest::AlternateConfiguration < RedisAdapterTest
  def cable_config
    alt_cable_config = super.dup
    alt_cable_config.delete(:url)
    url = URI(ENV["REDIS_URL"] || "")
    alt_cable_config.merge(host: url.hostname || "127.0.0.1", port: url.port || 6379, db: 12)
  end
end

class RedisAdapterTest::ConnectorDefaultID < ActionCable::TestCase
  def setup
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.merge(adapter: "redis").with_indifferent_access

    @adapter = server.config.pubsub_adapter.new(server)
  end

  def cable_config
    { url: "redis://example.com" }
  end

  def connection_id
    "ActionCable-PID-#{$$}"
  end

  def expected_connection
    cable_config.merge(id: connection_id)
  end

  test "sets connection id for connection" do
    client = @adapter.send(:redis_connection)
    if connection_id.nil?
      assert_nil client.id
    else
      assert_equal connection_id, client.id
    end
  end
end

class RedisAdapterTest::ConnectorCustomID < RedisAdapterTest::ConnectorDefaultID
  def cable_config
    super.merge(id: connection_id)
  end

  def connection_id
    "Some custom ID"
  end
end

class RedisAdapterTest::ConnectorCustomIDNil < RedisAdapterTest::ConnectorDefaultID
  def cable_config
    super.merge(id: connection_id)
  end

  def connection_id
    nil
  end
end

class RedisAdapterTest::ConnectorWithExcluded < RedisAdapterTest::ConnectorDefaultID
  def cable_config
    super.merge(adapter: "redis", channel_prefix: "custom")
  end

  def expected_connection
    super.except(:adapter, :channel_prefix)
  end
end

class RedisAdapterTest::SentinelConfigAsHash < ActionCable::TestCase
  def setup
    server = ActionCable::Server::Base.new
    server.config.cable = cable_config.merge(adapter: "redis").with_indifferent_access

    @adapter = server.config.pubsub_adapter.new(server)
  end

  def cable_config
    { url: "redis://test", sentinels: [{ "host" => "localhost", "port" => 26379 }] }
  end

  def expected_connection
    { url: "redis://test", sentinels: [{ host: "localhost", port: 26379 }], id: connection_id }
  end

  def connection_id
    "ActionCable-PID-#{$$}"
  end

  test "sets sentinels as array of hashes with keyword arguments" do
    redis_client = @adapter.send(:redis_connection)
    assert_kind_of RedisClient::SentinelConfig, redis_client.config
  end
end

class RedisAdapterTest::ListenerReconnection < ActionCable::TestCase
  # Drives the real Listener#listen/reset/resubscribe path with a fake pub/sub
  # connection so we can deterministically simulate a connection drop while a
  # subscription confirmation is still in flight. The blocking event queue is the
  # only point at which the listener loop advances, so the test fully controls the
  # ordering of the drop and the acknowledgements; no real Redis is involved.
  class FakePubSub
    def initialize(events)
      @events = events
    end

    def call(*)
    end

    def next_event(_timeout)
      event = @events.pop
      raise RedisClient::ConnectionError, "connection dropped" if event == :drop
      event
    end
  end

  class FakeConnection
    def initialize(pubsub)
      @pubsub = pubsub
    end

    attr_reader :pubsub
  end

  class FakeAdapter
    def initialize(connection)
      @connection = connection
    end

    def redis_connection_for_subscriptions
      @connection
    end

    def logger
      nil
    end
  end

  # Runs posted work inline so the test stays single-threaded apart from the
  # listener loop itself.
  class InlineExecutor
    def post(task = nil, &block)
      (task || block).call
    end
  end

  test "an in-flight subscription confirmation is delivered after a reconnect" do
    events = Queue.new
    listener = ActionCable::SubscriptionAdapter::Redis::Listener.new(
      FakeAdapter.new(FakeConnection.new(FakePubSub.new(events))), {}, InlineExecutor.new
    )

    confirmed = Concurrent::Event.new
    listener.add_subscriber("channel", ->(_message) { }, -> { confirmed.set })

    # The "subscribe" acknowledgement never arrives before the connection drops,
    # so the confirmation is still pending when the listener resets...
    events << :drop
    # ...and after it reconnects and re-subscribes, the acknowledgement for the
    # still-pending subscription must fire its confirmation callback.
    events << ["subscribe", "channel", 1]

    assert confirmed.wait(2), "expected the in-flight subscription confirmation to be delivered after reconnect"
  ensure
    listener.instance_variable_get(:@thread)&.kill
  end
end
