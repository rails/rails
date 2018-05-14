# frozen_string_literal: true

require "test_helper"
require_relative "common"
require_relative "channel_prefix"

require "active_support/testing/method_call_assertions"
require "action_cable/subscription_adapter/redis"

class RedisAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest
  include ChannelPrefixTest

  def cable_config
    { adapter: "redis", driver: "ruby" }
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
    alt_cable_config.merge(host: "127.0.0.1", port: 6379, db: 12)
  end
end

class RedisAdapterTest::Connector < ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions

  test "slices url, host, port, db, and password from config" do
    config = { url: 1, host: 2, port: 3, db: 4, password: 5 }

    assert_called_with ::Redis, :new, [ config ] do
      connect config.merge(other: "unrelated", stuff: "here")
    end
  end

  def connect(config)
    ActionCable::SubscriptionAdapter::Redis.redis_connector.call(config)
  end
end
