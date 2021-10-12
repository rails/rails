# frozen_string_literal: true

require "test_helper"
require_relative "common"
require_relative "channel_prefix"

require "action_cable/subscription_adapter/redis"

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
end

class RedisAdapterTest::Hiredis < RedisAdapterTest
  def cable_config
    super.merge(driver: "hiredis")
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
    assert_called_with ::Redis, :new, [ expected_connection.stringify_keys ] do
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
