# frozen_string_literal: true

class SuccessAdapter < ActionCable::SubscriptionAdapter::Base
  class << self; attr_accessor :subscribe_called, :unsubscribe_called end

  def broadcast(channel, payload)
  end

  def subscribe(channel, callback, success_callback = nil)
    @@subscribe_called = { channel: channel, callback: callback, success_callback: success_callback }
  end

  def unsubscribe(channel, callback)
    @@unsubscribe_called = { channel: channel, callback: callback }
  end
end
