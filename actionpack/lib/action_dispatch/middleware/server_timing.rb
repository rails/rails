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
      ActiveSupport::Notifications.subscribe(/.*/) do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      status, headers, body = @app.call(env)

      header_info = []
      events.group_by(&:name).each do |event_name, events_collection|
        header_info << "#{event_name};dur=#{duration_sum(events_collection)}"
      end
      headers[SERVER_TIMING_HEADER] = header_info.join(", ")

      [ status, headers, body ]
    end

    private

      def duration_sum(events)
        events.reduce(0) { |sum, event| sum + event.duration }
      end
  end
end
