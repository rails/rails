# frozen_string_literal: true

require "active_support/notifications"

module ActionDispatch
  class ServerTiming
    SERVER_TIMING_HEADER = "Server-Timing"

    def initialize(app)
      @app = app
    end

    def call(env)
      events = []
      subscriber = ActiveSupport::Notifications.subscribe(/.*/) do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      status, headers, body = @app.call(env)
      ActiveSupport::Notifications.unsubscribe(subscriber)

      header_info = events.group_by(&:name).map do |event_name, events_collection|
        "#{event_name};dur=#{events_collection.sum(&:duration)}"
      end
      headers[SERVER_TIMING_HEADER] = header_info.join(", ")

      [ status, headers, body ]
    end
  end
end
