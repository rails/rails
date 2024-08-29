
# typed: true
# frozen_string_literal: true

module ActiveSupport
  module Testing
    module InstrumentationAssertions
      # Assert an event was emitted with a given +pattern+ and optional +payload+.
      #
      # You can assert that an event was emitted by passing a pattern, which accepts
      # either a string or regexp, an optional payload, and a block. While the block
      # is executed, if a matching event is emitted, the assertion will pass.
      #
      #     assert_instrumentation_event("post.submitted", title: "Cool Post") do
      #       post.submit(title: "Cool Post") # => emits matching ActiveSupport::Notifications::Event
      #     end
      #
      def assert_instrumentation_event(pattern, payload = nil, &block)
        events = capture_instrumentation_events(pattern, &block)
        assert_not_empty(events, "No #{pattern} events were found")

        return if payload.nil?

        event = events.find { |event| event.payload == payload }
        assert_not_nil(event, "No #{pattern} event with payload #{payload} was found")
      end

      # Assert the number of events emitted with a given +pattern+.
      #
      # You can assert the number of events emitted by passing a pattern, which accepts
      # either a string or regexp, a count, and a block. While the block is executed,
      # the number of matching events emitted will be counted. After the block's
      # execution completes, the assertion will pass if the count matches.
      #
      #     assert_instrumentation_events_count("post.submitted", 1) do
      #       post.submit(title: "Cool Post") # => emits matching ActiveSupport::Notifications::Event
      #     end
      #
      def assert_instrumentation_events_count(pattern, count, &block)
        actual_count = capture_instrumentation_events(pattern, &block).count
        assert_equal(count, actual_count, "Expected #{count} instead of #{actual_count} events for #{pattern}")
      end

      # Assert no events were emitted for a given +pattern+.
      #
      # You can assert no events were emitted by passing a pattern, which accepts
      # either a string or regexp, and a block. While the block is executed, if no
      # matching events are emitted, the assertion will pass.
      #
      #     assert_no_instrumentation_events("post.submitted") do
      #       post.destroy # => emits non-matching ActiveSupport::Notifications::Event
      #     end
      #
      def assert_no_instrumentation_events(pattern = nil, &block)
        events = capture_instrumentation_events(pattern, &block)
        error_message = if pattern
          "Expected no events for #{pattern} but found #{events.size}"
        else
          "Expected no events but found #{events.size}"
        end
        assert_empty(events, error_message)
      end

      # Capture emitted events, optionally filtered by a +pattern+.
      #
      # You can capture emitted events, optionally filtered by a pattern,
      # which accepts either a string or regexp, and a block.
      #
      #     events = capture_instrumentation_events("post.submitted") do
      #       post.submit(title: "Cool Post") # => emits matching ActiveSupport::Notifications::Event
      #     end
      #
      def capture_instrumentation_events(pattern = nil, &block)
        events = []
        ActiveSupport::Notifications.subscribed(->(e) { events << e }, pattern, &block)
        events
      end
    end
  end
end
