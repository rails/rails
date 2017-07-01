require "test_helper"

class ActionCable::Server::WithIndependentConfig < ActionCable::Server::Base
  # ActionCable::Server::Base defines config as a class variable.
  # Need config to be an instance variable here as we're testing 2 separate configs
  def config
    @config ||= ActionCable::Server::Configuration.new
  end
end

module ChannelPrefixTest
  def test_channel_prefix
    server2 = ActionCable::Server::WithIndependentConfig.new
    server2.config.cable = alt_cable_config
    server2.config.logger = Logger.new(StringIO.new).tap { |l| l.level = Logger::UNKNOWN }

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

  def alt_cable_config
    cable_config.merge(channel_prefix: "foo")
  end
end
