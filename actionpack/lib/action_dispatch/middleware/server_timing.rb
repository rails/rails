# frozen_string_literal: true

require "action_dispatch/middleware/server_timing_subscriber"

module ActionDispatch
  class ServerTiming
    SERVER_TIMING_HEADER = "Server-Timing"

    class << self
      def add_timing(key:, dur: nil, desc: nil)
        timings[key] = { dur: dur, desc: desc }
      end

      def to_header
        metrics = []
        timings.each_pair do |key, data|
          metric = +key.to_s
          metric << ";desc=\"#{data[:desc]}\"" if data[:desc]
          metric << ";dur=#{data[:dur]}" if data[:dur]
          metrics << metric
        end
        metrics.join(", ")
      end

      def measure(key, desc: nil, &blk)
        ActiveSupport::Notifications.instrument("measure.server_timing", desc: desc, key: key) do
          yield
        end
      end

      def timings
        Thread.current[:server_timing] ||= {}
      end

      def clear_timings!
        Thread.current[:server_timing] = {}
      end
    end

    def initialize(app, events: [], all_events: false)
      @app = app
      if all_events
        subscribe_to_all_events
      else
        subscribe_to_events(events)
      end
    end

    def call(env)
      @app.call(env).tap do |_, headers, _|
        add_timing_headers(headers)
      end
    ensure
      self.class.clear_timings!
    end

    private

      def add_timing_headers(headers)
        headers[SERVER_TIMING_HEADER] = self.class.to_header
      end

      def subscribe_to_all_events
        ActiveSupport::Notifications.subscribe(/.*/) do |*args|
          event = ActiveSupport::Notifications::Event.new(*args)

          ServerTiming.add_timing(
            key: event.payload.dig(:server_timing, :key) || event.name,
            dur: event.duration,
            desc: event.payload.dig(:server_timing, :desc)
          )
        end
      end

      def subscribe_to_events(events_config)
        events_config.each do |event_config|
          if event_config.is_a?(String)
            ActiveSupport::Notifications.subscribe(event_config) do |*args|
              event = ActiveSupport::Notifications::Event.new(*args)

              ServerTiming.add_timing(
                key: event.payload.dig(:server_timing, :key) || event.name,
                dur: event.duration,
                desc: event.payload.dig(:server_timing, :desc)
              )
            end
          else
            event_name, keys = event_config.first
            keys.each do |key|
              ActiveSupport::Notifications.subscribe(event_name) do |*args|
                event = ActiveSupport::Notifications::Event.new(*args)

                ServerTiming.add_timing(
                  key: key,
                  dur: event.payload.fetch(key),
                  desc: event.payload.dig(:server_timing, :desc)
                )
              end
            end
          end
        end
      end
  end
end
