# frozen_string_literal: true

class SuccessAdapter < ActionCable::SubscriptionAdapter::Base
  def broadcast(channel, payload)
  end

  def subscribe(channel, callback, success_callback = nil)
    @@subscribe_called = { channel: channel, callback: callback, success_callback: success_callback }
  end

  def unsubscribe(channel, callback)
    @@unsubscribe_called = { channel: channel, callback: callback }
  end
end
