# frozen_string_literal: true

require "test_helper"
require_relative "common"
require_relative "channel_prefix"

class RabbitmqAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest
  include ChannelPrefixTest

  def cable_config
    { adapter: "rabbitmq" }
  end
end
