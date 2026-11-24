# frozen_string_literal: true

require "test_helper"
require "minitest/mock"
require "stubs/test_socket"
require "stubs/room"

class ActionCable::Channel::RejectionTest < ActionCable::TestCase
  class SecretChannel < ActionCable::Channel::Base
    def subscribed
      reject if params[:id] > 0
    end

    def secret_action
    end
  end

  setup do
    @user = User.new "lifo"
    @connection = TestSocket.new(@user)
  end

  test "subscription rejection" do
    subscriptions = Minitest::Mock.new
    subscriptions.expect(:remove_subscription, SecretChannel, [SecretChannel])

    @connection.stub(:subscriptions, subscriptions) do
      @channel = SecretChannel.new @connection, "{id: 1}", id: 1
      @channel.subscribe_to_channel

      expected = { "identifier" => "{id: 1}", "type" => "reject_subscription" }
      assert_equal expected, @connection.last_transmission
    end

    assert subscriptions.verify
  end

  test "does not execute action if subscription is rejected" do
    subscriptions = Minitest::Mock.new
    subscriptions.expect(:remove_subscription, SecretChannel, [SecretChannel])

    @connection.stub(:subscriptions, subscriptions) do
      @channel = SecretChannel.new @connection, "{id: 1}", id: 1
      @channel.subscribe_to_channel

      expected = { "identifier" => "{id: 1}", "type" => "reject_subscription" }
      assert_equal expected, @connection.last_transmission
      assert_equal 1, @connection.transmissions.size

      @channel.perform_action("action" => :secret_action)
      assert_equal 1, @connection.transmissions.size
    end

    assert subscriptions.verify
  end

  class StreamingAfterRejectChannel < ActionCable::Channel::Base
    def subscribed
      reject
      stream_from "secret"
    end
  end

  class StreamingBeforeRejectChannel < ActionCable::Channel::Base
    def subscribed
      stream_from "secret"
      reject
    end
  end

  [StreamingAfterRejectChannel, StreamingBeforeRejectChannel].each do |channel_class|
    test "#{channel_class.name.demodulize} is not streamed to after rejection when the adapter changes subscribers out of order" do
      executor = OutOfOrderExecutor.new
      server = TestServer.new(subscription_adapter: ActionCable::SubscriptionAdapter::Async)
      server.stub(:executor, executor) do
        @connection.stub(:server, -> { server }) do
          channel = channel_class.new @connection, "{id: 1}", id: 1
          channel.subscribe_to_channel
          executor.run_all

          server.pubsub.broadcast("secret", ActiveSupport::JSON.encode(message: "secret"))
          executor.run_all
        end
      end

      assert_equal [{ "identifier" => "{id: 1}", "type" => "reject_subscription" }], @connection.transmissions.map { |t| @connection.decode(t) }
    end
  end
end
