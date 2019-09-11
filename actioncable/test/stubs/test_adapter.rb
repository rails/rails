# frozen_string_literal: true

class SuccessAdapter < ActionCable::SubscriptionAdapter::Base
  def broadcast(channel, payload)
  end

  def subscribe(channel, callback, success_callback = nil)
    subscriber_map.add_subscriber(channel, callback, success_callback)
    @@subscribe_called = { channel: channel, callback: callback, success_callback: success_callback }
  end

  def unsubscribe(channel, callback)
    subscriber_map.remove_subscriber(channel, callback)
    @@unsubscribe_called = { channel: channel, callback: callback }
  end

  def subscriber_map
    @subscriber_map ||= ActionCable::SubscriptionAdapter::SubscriberMap.new
  end
end
