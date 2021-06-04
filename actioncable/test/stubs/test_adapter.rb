# frozen_string_literal: true

class SuccessAdapter < ActionCable::SubscriptionAdapter::Base
  def broadcast(channel, payload)
  end

  def subscribe(channel, callback, success_callback = nil)
    subscriber_map[channel] << callback
    @@subscribe_called = { channel: channel, callback: callback, success_callback: success_callback }
  end

  def unsubscribe(channel, callback)
    subscriber_map[channel].delete(callback)
    subscriber_map.delete(channel) if subscriber_map[channel].empty?
    @@unsubscribe_called = { channel: channel, callback: callback }
  end

  def subscriber_map
    @subscribers ||= Hash.new { |h, k| h[k] = [] }
  end
end
