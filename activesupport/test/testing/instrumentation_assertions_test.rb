# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/testing/instrumentation_assertions"

module ActiveSupport
  module Testing
    class InstrumentationAssertionsTest < ActiveSupport::TestCase
      include InstrumentationAssertions

      def test_assert_instrumentation_event
        assert_instrumentation_event("post.submitted", title: "Cool Post") do
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_instrumentation_event("post.submitted") do # payload omitted
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_raises(Minitest::Assertion, match: /No post.submitted events were found/) {
          assert_instrumentation_event("post.submitted", title: "Cool Post") { nil } # no events
        }

        assert_raises(Minitest::Assertion, match: /No post.submitted event with payload {:title=>"Cool Post"} was found/) {
          assert_instrumentation_event("post.submitted", title: "Cool Post") do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cooler Post")
          end
        }
      end

      def test_assert_instrumentation_events_count
        assert_instrumentation_events_count("post.submitted", 1) do
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_raises(Minitest::Assertion, match: /Expected 1 instead of 2 events for post.submitted/) {
          assert_instrumentation_events_count("post.submitted", 1) do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cooler Post")
          end
        }

        assert_raises(Minitest::Assertion, match: /Expected 1 instead of 0 events for post.submitted/) {
          assert_instrumentation_events_count("post.submitted", 1) { nil } # no events
        }
      end

      def test_assert_no_instrumentation_events
        assert_no_instrumentation_events("post.submitted") { nil } # no events

        assert_raises(Minitest::Assertion, match: /Expected no events for post.submitted but found 1/) {
          assert_no_instrumentation_events("post.submitted") do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
          end
        }

        assert_raises(Minitest::Assertion, match: /Expected no events but found 1/) {
          assert_no_instrumentation_events do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
          end
        }
      end

      def test_capture_instrumentation_events
        events = capture_instrumentation_events("post.submitted") do # string pattern
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_equal(1, events.size)
        assert_equal("post.submitted", events.first.name)
        assert_equal({ title: "Cool Post" }, events.first.payload)

        events = capture_instrumentation_events(/post\./) do # regexp pattern
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_equal(1, events.size)
        assert_equal("post.submitted", events.first.name)
        assert_equal({ title: "Cool Post" }, events.first.payload)

        events = capture_instrumentation_events do # no pattern
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_equal(1, events.size)
        assert_equal("post.submitted", events.first.name)
        assert_equal({ title: "Cool Post" }, events.first.payload)

        events = capture_instrumentation_events("post.submitted") { nil } # no events

        assert_empty(events)
      end
    end
  end
end
