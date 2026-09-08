# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/event_reporter_assertions"
require "rails/structured_event_subscriber"

module Rails
  class StructuredEventSubscriberTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::EventReporterAssertions

    def test_deprecation_is_notified_when_behavior_is_notify
      Rails.deprecator.with(behavior: :notify) do
        event = assert_event_reported("rails.deprecation", payload: { gem_name: "Rails" }) do
          Rails.deprecator.warn("This is a deprecation warning")
        end

        assert_includes event[:payload][:message], "This is a deprecation warning"
        assert_includes event[:payload].keys, :callstack
        assert_includes event[:payload].keys, :gem_name
        assert_includes event[:payload].keys, :deprecation_horizon
      end
    end

    def test_deprecation_is_not_notified_when_behavior_is_not_notify
      Rails.deprecator.with(behavior: :stderr) do
        output = capture(:stderr) do
          assert_no_event_reported("rails.deprecation") do
            Rails.deprecator.warn("This is a deprecation warning")
          end
        end

        assert_includes output, "This is a deprecation warning"
      end
    end
  end
end
