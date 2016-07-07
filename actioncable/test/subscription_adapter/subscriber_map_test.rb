require 'test_helper'

class SubscriberMapTest < ActionCable::TestCase
  test "broadcast should not change subscribers" do
    setup_subscription_map
    origin = @subscription_map.instance_variable_get(:@subscribers).dup

    @subscription_map.broadcast('not_exist_channel', '')

    assert_equal origin, @subscription_map.instance_variable_get(:@subscribers)
  end

  private
    def setup_subscription_map
      @subscription_map = ActionCable::SubscriptionAdapter::SubscriberMap.new
    end
end
