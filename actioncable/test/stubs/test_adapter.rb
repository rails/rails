# frozen_string_literal: true

class SuccessAdapter < ActionCable::SubscriptionAdapter::Base
  def broadcast(channel, payload)
  end

  def subscribe(channel, callback, success_callback = nil)
  end

  def unsubscribe(channel, callback)
  end
end
