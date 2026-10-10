# frozen_string_literal: true

require "abstract_unit"
require "active_support/testing/event_reporter_assertions"

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

    def test_built_in_subscribers_declare_the_namespace_they_are_attached_to
      %w[
        action_controller action_dispatch action_mailer action_view
        active_job active_record active_storage
      ].each { |framework| require "#{framework}/structured_event_subscriber" }

      subscribers = ActiveSupport::Subscriber.subscribers.grep(ActiveSupport::StructuredEventSubscriber)
      namespaces = subscribers.filter_map { |subscriber| subscriber.class.event_namespace }

      assert_equal %w[action_controller action_dispatch action_mailer action_view active_job active_record active_storage rails], namespaces.sort
      subscribers.each do |subscriber|
        next unless namespace = subscriber.class.event_namespace

        assert_not_empty subscriber.patterns
        subscriber.patterns.each_key do |pattern|
          assert pattern.end_with?(".#{namespace}"), "#{subscriber.class} is attached to #{pattern}, outside of #{namespace}"
        end
      end
    end
  end
end
