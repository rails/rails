# frozen_string_literal: true

require "active_support/subscriber"

module ActionDispatch
  class ServerTimingSubscriber < ActiveSupport::Subscriber
    def measure(event)
      ServerTiming.add_timing(
        key: event.payload[:key],
        desc: event.payload[:desc],
        dur: event.duration
      )
    end
  end

  ServerTimingSubscriber.attach_to :server_timing
end
