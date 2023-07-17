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
      @redis_conn ||= ::Redis.new(cable_config.except(:adapter))
    end

    def drop_pubsub_connections
      # Emulate connection failure by dropping all connections
      redis_conn.client("kill", "type", "pubsub")
    end

    def wait_pubsub_connection(redis_conn, channel, timeout: 5)
      wait = timeout
      loop do
        break if redis_conn.pubsub("numsub", channel).last > 0

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
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

    @adapter = server.config.pubsub_adapter.new(server)
  end

  def cable_config
    { url: 1, host: 2, port: 3, db: 4, password: 5 }
  end

  def connection_id
    "ActionCable-PID-#{$$}"
  end

  def expected_connection
    cable_config.merge(id: connection_id)
  end

  test "sets connection id for connection" do
    assert_called_with ::Redis, :new, [ expected_connection.symbolize_keys ] do
      @adapter.send(:redis_connection)
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
    server.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

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
    assert_called_with ::Redis, :new, [ expected_connection ] do
      @adapter.send(:redis_connection)
    end
  end
end
