# typed: true
# frozen_string_literal: true

module ActiveSupport
  module Testing
    # Provides test helpers for asserting on ActiveSupport::EventReporter events.
    module EventReporterAssertions
      module EventCollector # :nodoc:
        @subscribed = false
        @mutex = Mutex.new

        class Event # :nodoc:
          attr_reader :event_data

          def initialize(event_data)
            @event_data = event_data
          end

          def inspect
            "#{event_data[:name]} (payload: #{event_data[:payload].inspect}, tags: #{event_data[:tags].inspect})"
          end

          def matches?(name, payload, tags)
            return false unless name.to_s == event_data[:name]

            if payload && payload.is_a?(Hash)
              return false unless matches_hash?(payload, :payload)
            end

            return false unless matches_hash?(tags, :tags)
            true
          end

          private
            def matches_hash?(expected_hash, event_key)
              expected_hash.all? do |k, v|
                if v.is_a?(Regexp)
                  event_data.dig(event_key, k).to_s.match?(v)
                else
                  event_data.dig(event_key, k) == v
                end
              end
            end
        end

        class << self
          def emit(event)
            event_recorders&.each do |events|
              events << Event.new(event)
            end
            true
          end

          def record
            subscribe
            events = []
            event_recorders << events
            begin
              yield
              events
            ensure
              event_recorders.delete_if { |r| events.equal?(r) }
            end
          end

          private
            def subscribe
              return if @subscribed

              @mutex.synchronize do
                unless @subscribed
                  if ActiveSupport.event_reporter
                    ActiveSupport.event_reporter.subscribe(self)
                    @subscribed = true
                  else
                    raise Minitest::Assertion, "No event reporter is configured"
                  end
                end
              end
            end

            def event_recorders
              ActiveSupport::IsolatedExecutionState[:active_support_event_reporter_assertions] ||= []
            end
        end
      end

      # Asserts that the block does not cause an event to be reported to +Rails.event+.
      #
      # If no name is provided, passes if evaluated code in the yielded block reports no events.
      #
      #   assert_no_event_reported do
      #     service_that_does_not_report_events.perform
      #   end
      #
      # If a name is provided, passes if evaluated code in the yielded block reports no events
      # with that name.
      #
      #   assert_no_event_reported("user.created") do
      #     service_that_does_not_report_events.perform
      #   end
      def assert_no_event_reported(name = nil, payload: {}, tags: {}, &block)
        events = EventCollector.record(&block)

        if name.nil?
          assert_predicate(events, :empty?)
        else
          matching_event = events.find { |event| event.matches?(name, payload, tags) }
          if matching_event
            message = "Expected no '#{name}' event to be reported, but found:\n  " \
              "#{matching_event.inspect}"
            flunk(message)
          end
          assert(true)
        end
      end

      # Asserts that the block causes an event with the given name to be reported
      # to +Rails.event+.
      #
      # Passes if the evaluated code in the yielded block reports a matching event.
      #
      #   assert_event_reported("user.created") do
      #     Rails.event.notify("user.created", { id: 123 })
      #   end
      #
      # To test further details about the reported event, you can specify payload and tag matchers.
      #
      #   assert_event_reported("user.created",
      #     payload: { id: 123, name: "John Doe" },
      #     tags: { request_id: /[0-9]+/ }
      #   ) do
      #     Rails.event.tagged(request_id: "123") do
      #       Rails.event.notify("user.created", { id: 123, name: "John Doe" })
      #     end
      #   end
      #
      # The matchers support partial matching - only the specified keys need to match.
      #
      #   assert_event_reported("user.created", payload: { id: 123 }) do
      #     Rails.event.notify("user.created", { id: 123, name: "John Doe" })
      #   end
      def assert_event_reported(name, payload: nil, tags: {}, &block)
        events = EventCollector.record(&block)

        if events.empty?
          flunk("Expected an event to be reported, but there were no events reported.")
        elsif (event = events.find { |event| event.matches?(name, payload, tags) })
          assert(true)
          event.event_data
        else
          message = "Expected an event to be reported matching:\n  " \
            "name: #{name}\n  " \
            "payload: #{payload.inspect}\n  " \
            "tags: #{tags.inspect}\n" \
            "but none of the #{events.size} reported events matched:\n  " \
            "#{events.map(&:inspect).join("\n  ")}"
          flunk(message)
        end
      end
    end
  end
end
