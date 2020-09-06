# frozen_string_literal: true

require 'test_helper'
require_relative 'common'

class ActionCable::SubscriptionAdapter::TestTest < ActionCable::TestCase
  include CommonSubscriptionAdapterTest

  def setup
    super

    @tx_adapter.shutdown
    @tx_adapter = @rx_adapter
  end

  def cable_config
    { adapter: 'test' }
  end

  test '#broadcast stores messages for streams' do
    @tx_adapter.broadcast('channel', 'payload')
    @tx_adapter.broadcast('channel2', 'payload2')

    assert_equal ['payload'], @tx_adapter.broadcasts('channel')
    assert_equal ['payload2'], @tx_adapter.broadcasts('channel2')
  end

  test '#clear_messages deletes recorded broadcasts for the channel' do
    @tx_adapter.broadcast('channel', 'payload')
    @tx_adapter.broadcast('channel2', 'payload2')

    @tx_adapter.clear_messages('channel')

    assert_equal [], @tx_adapter.broadcasts('channel')
    assert_equal ['payload2'], @tx_adapter.broadcasts('channel2')
  end

  test '#clear deletes all recorded broadcasts' do
    @tx_adapter.broadcast('channel', 'payload')
    @tx_adapter.broadcast('channel2', 'payload2')

    @tx_adapter.clear

    assert_equal [], @tx_adapter.broadcasts('channel')
    assert_equal [], @tx_adapter.broadcasts('channel2')
  end
end
