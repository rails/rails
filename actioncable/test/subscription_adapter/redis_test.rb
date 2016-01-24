require 'test_helper'
require_relative './common'

class RedisAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest

  def cable_config
    { adapter: 'redis', url: 'redis://127.0.0.1:6379/12' }
  end
end
