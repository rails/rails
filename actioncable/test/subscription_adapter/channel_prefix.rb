# frozen_string_literal: true

require "test_helper"

module ChannelPrefixTest
  def test_channel_prefix
    server2 = ActionCable::Server::Base.new(config: ActionCable::Server::Configuration.new)
    server2.config.cable = alt_cable_config.with_indifferent_access

    adapter_klass = server2.config.pubsub_adapter

    rx_adapter2 = adapter_klass.new(server2)
    tx_adapter2 = adapter_klass.new(server2)

    subscribe_as_queue("channel") do |queue|
      subscribe_as_queue("channel", rx_adapter2) do |queue2|
        @tx_adapter.broadcast("channel", "hello world")
        tx_adapter2.broadcast("channel", "hello world 2")

        assert_equal "hello world", queue.pop
        assert_equal "hello world 2", queue2.pop
      end
    end
  end

  def test_channel_prefix_in_a_broadcast_batch
    server2 = ActionCable::Server::Base.new(config: ActionCable::Server::Configuration.new)
    server2.config.cable = alt_cable_config.with_indifferent_access

    adapter_klass = server2.config.pubsub_adapter

    rx_adapter2 = adapter_klass.new(server2)
    tx_adapter2 = adapter_klass.new(server2)

    subscribe_as_queue("channel") do |queue|
      subscribe_as_queue("channel", rx_adapter2) do |queue2|
        @tx_adapter.broadcast_batch([["channel", "hello world"]])
        tx_adapter2.broadcast_batch([["channel", "hello world 2"]])

        assert_equal "hello world", queue.pop(timeout: CommonSubscriptionAdapterTest::WAIT_WHEN_EXPECTING_EVENT)
        assert_equal "hello world 2", queue2.pop(timeout: CommonSubscriptionAdapterTest::WAIT_WHEN_EXPECTING_EVENT)
      end
    end
  ensure
    [rx_adapter2, tx_adapter2].compact.each(&:shutdown)
  end

  def alt_cable_config
    cable_config.merge(channel_prefix: "foo")
  end
end
