# frozen_string_literal: true

require "test_helper"
require_relative "common"
require_relative "channel_prefix"

class RabbitmqAdapterTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest
  include ChannelPrefixTest

  def setup
    super
    unless rabbimt_mq_is_ready?
      skip "RabbitMQ is not ready." if ENV["CI"]
    end
  end

  def cable_config
    { adapter: "rabbitmq" }
  end

  private
    def rabbimt_mq_is_ready?
      return @is_ready if defined? @is_ready
      @is_ready = begin
        @rx_adapter.send :listener
        true
      rescue Bunny::TCPConnectionFailedForAllHosts
        false
      end
    end
end
