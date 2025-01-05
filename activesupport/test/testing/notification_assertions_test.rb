# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/testing/notification_assertions"

module ActiveSupport
  module Testing
    class NotificationAssertionsTest < ActiveSupport::TestCase
      include NotificationAssertions

      def test_assert_notification
        assert_notification("post.submitted", title: "Cool Post") do
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_notification("post.submitted", title: "Cool Post") do # subset of payload
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post", body: "Cool Body")
        end

        assert_notification("post.submitted") do # payload omitted
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_raises(Minitest::Assertion, match: /No post.submitted notifications were found/) do
          assert_notification("post.submitted", title: "Cool Post") { nil } # no notifications
        end

        match = if RUBY_VERSION >= "3.4"
          /No post.submitted notification with payload {title: "Cool Post"} was found/
        else
          /No post.submitted notification with payload {:title=>"Cool Post"} was found/
        end
        assert_raises(Minitest::Assertion, match:) do
          assert_notification("post.submitted", title: "Cool Post") do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cooler Post")
          end
        end

        notification = assert_notification("post.submitted") do # returns notification, no payload specified
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end
        assert_equal("post.submitted", notification.name)

        notification = assert_notification("post.submitted", title: "Cool Post") do # returns notification
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end
        assert_equal("post.submitted", notification.name)
      end

      def test_assert_notifications_count
        assert_notifications_count("post.submitted", 1) do
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_raises(Minitest::Assertion, match: /Expected 1 instead of 2 notifications for post.submitted/) do
          assert_notifications_count("post.submitted", 1) do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cooler Post")
          end
        end

        assert_raises(Minitest::Assertion, match: /Expected 1 instead of 0 notifications for post.submitted/) do
          assert_notifications_count("post.submitted", 1) { nil } # no notifications
        end
      end

      def test_assert_no_notifications
        assert_no_notifications("post.submitted") { nil } # no notifications

        assert_raises(Minitest::Assertion, match: /Expected no notifications for post.submitted but found 1/) do
          assert_no_notifications("post.submitted") do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
          end
        end

        assert_raises(Minitest::Assertion, match: /Expected no notifications but found 1/) do
          assert_no_notifications do
            ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
          end
        end
      end

      def test_capture_notifications
        notifications = capture_notifications("post.submitted") do # string pattern
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_equal(1, notifications.size)
        assert_equal("post.submitted", notifications.first.name)
        assert_equal({ title: "Cool Post" }, notifications.first.payload)

        notifications = capture_notifications(/post\./) do # regexp pattern
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_equal(1, notifications.size)
        assert_equal("post.submitted", notifications.first.name)
        assert_equal({ title: "Cool Post" }, notifications.first.payload)

        notifications = capture_notifications do # no pattern
          ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post")
        end

        assert_equal(1, notifications.size)
        assert_equal("post.submitted", notifications.first.name)
        assert_equal({ title: "Cool Post" }, notifications.first.payload)

        notifications = capture_notifications("post.submitted") { nil } # no notifications

        assert_empty(notifications)
      end
    end
  end
end
