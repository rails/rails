# frozen_string_literal: true

# :markup: markdown

require "active_support/notifications"

module ActionDispatch
  class ServerTiming
    class Subscriber # :nodoc:
      include Singleton
      KEY = :action_dispatch_server_timing_events

      def initialize
        @mutex = Mutex.new
      end

      def call(event)
        if events = ActiveSupport::IsolatedExecutionState[KEY]
          events << event
        end
      end

      def collect_events
        events = []
        ActiveSupport::IsolatedExecutionState[KEY] = events
        yield
        events
      ensure
        ActiveSupport::IsolatedExecutionState.delete(KEY)
      end

      def ensure_subscribed
        @mutex.synchronize do
          # Subscribe to all events, except those beginning with "!" Ideally we would be
          # more selective of what is being measured
          @subscriber ||= ActiveSupport::Notifications.subscribe(/\A[^!]/, self)
        end
      end

      def unsubscribe
        @mutex.synchronize do
          ActiveSupport::Notifications.unsubscribe @subscriber
          @subscriber = nil
        end
      end
    end

    def self.unsubscribe # :nodoc:
      Subscriber.instance.unsubscribe
    end

    def initialize(app)
      @app = app
      @subscriber = Subscriber.instance
      @subscriber.ensure_subscribed
    end

    def call(env)
      response = nil
      events = @subscriber.collect_events do
        response = @app.call(env)
      end

      headers = response[1]

      header_info = events.group_by(&:name).map do |event_name, events_collection|
        "%s;dur=%.2f" % [event_name, events_collection.sum(&:duration)]
      end

      if headers[ActionDispatch::Constants::SERVER_TIMING].present?
        header_info.prepend(headers[ActionDispatch::Constants::SERVER_TIMING])
      end
      headers[ActionDispatch::Constants::SERVER_TIMING] = header_info.join(", ")

      response
    end
  end
end
