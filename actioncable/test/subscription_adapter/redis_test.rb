require "test_helper"
require_relative "./common"
require_relative "./channel_prefix"

class RedisAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest
  include ChannelPrefixTest

  def cable_config
    { adapter: "redis", driver: "ruby", url: "redis://127.0.0.1:6379/12" }
  end
end

class RedisAdapterTest::Hiredis < RedisAdapterTest
  def cable_config
    super.merge(driver: "hiredis")
  end
end
