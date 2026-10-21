# frozen_string_literal: true

require "test_helper"

class SubscriberMapTest < ActionCable::TestCase
  test "broadcast should not change subscribers" do
    setup_subscription_map
    origin = @subscription_map.instance_variable_get(:@subscribers).dup

    @subscription_map.broadcast("not_exist_channel", "")

    assert_equal origin, @subscription_map.instance_variable_get(:@subscribers)
  end

  test "remove_subscriber from an unknown channel does not trigger remove_channel" do
    setup_subscription_map
    origin = @subscription_map.instance_variable_get(:@subscribers).dup

    assert_not_called(@subscription_map, :remove_channel) do
      @subscription_map.remove_subscriber("not_exist_channel", "subscriber")
    end

    assert_equal origin, @subscription_map.instance_variable_get(:@subscribers)
  end

  test "remove_subscriber for an absent subscriber on a known channel does not trigger remove_channel" do
    setup_subscription_map
    @subscription_map.add_subscriber("channel", "subscriber", nil)
    origin = @subscription_map.instance_variable_get(:@subscribers).dup

    assert_not_called(@subscription_map, :remove_channel) do
      @subscription_map.remove_subscriber("channel", "other_subscriber")
    end

    assert_equal origin, @subscription_map.instance_variable_get(:@subscribers)
  end

  test "broadcast encodes a message once per identifier" do
    setup_subscription_map
    received = []
    received2 = []
    @subscription_map.add_subscriber("channel", ->(message) { received << message.encoded_for("id-1") }, nil)
    @subscription_map.add_subscriber("channel", ->(message) { received << message.encoded_for("id-1") }, nil)
    @subscription_map.add_subscriber("channel", ->(message) { received2 << message.encoded_for("id-2") }, nil)

    @subscription_map.broadcast("channel", %({"foo":"bar"}))

    assert_equal 2, received.size
    assert_same received[0], received[1]
    assert_equal 1, received2.size

    assert_equal({ "identifier" => "id-1", "message" => { "foo" => "bar" } }, ActiveSupport::JSON.decode(received[0]))
    assert_equal({ "identifier" => "id-2", "message" => { "foo" => "bar" } }, ActiveSupport::JSON.decode(received2[0]))
  end

  private
    def setup_subscription_map
      @subscription_map = ActionCable::SubscriptionAdapter::SubscriberMap.new
    end
end
