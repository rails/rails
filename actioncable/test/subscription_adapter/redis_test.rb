require 'test_helper'
require_relative './common'

class RedisAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest

  def cable_config
    host = ENV.fetch('REDIS_PORT_6379_TCP_ADDR', '127.0.0.1')
    port = ENV.fetch('REDIS_PORT_6379_TCP_PORT', 6379)

    { adapter: 'redis', driver: 'ruby', url: "redis://#{host}:#{port}/12" }
  end
end

class RedisAdapterTest::Hiredis < RedisAdapterTest
  def cable_config
    super.merge(driver: 'hiredis')
  end
end
