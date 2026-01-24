# frozen_string_literal: true

module ActiveSupport
  module Testing
    module NotificationAssertions
      # Assert a notification was emitted with a given +pattern+ and optional +payload+.
      #
      # You can assert that a notification was emitted by passing a pattern, which accepts
      # either a string or regexp, an optional payload, and a block. While the block
      # is executed, if a matching notification is emitted, the assertion will pass
      # and the notification will be returned.
      #
      # Note that the payload is matched as a subset, meaning that the notification must
      # contain at least the specified keys and values, but may contain additional ones.
      #
      #     assert_notification("post.submitted", title: "Cool Post") do
      #       post.submit(title: "Cool Post", body: "Cool Body") # => emits matching notification
      #     end
      #
      # Using the returned notification, you can make more customized assertions.
      #
      #     notification = assert_notification("post.submitted", title: "Cool Post") do
      #       ActiveSupport::Notifications.instrument("post.submitted", title: "Cool Post", body: Body.new("Cool Body"))
      #     end
      #
      #     assert_instance_of(Body, notification.payload[:body])
      #
      def assert_notification(pattern, payload = nil, &block)
        notifications = capture_notifications(pattern, &block)
        assert_not_empty(notifications, "No #{pattern} notifications were found")

        return notifications.first if payload.nil?

        notification = notifications.find { |notification| notification.payload.slice(*payload.keys) == payload }
        assert_not_nil(notification, "No #{pattern} notification with payload #{payload} was found")

        notification
      end

      # Assert the number of notifications emitted with a given +pattern+.
      #
      # You can assert the number of notifications emitted by passing a pattern, which accepts
      # either a string or regexp, a count, and a block. While the block is executed,
      # the number of matching notifications emitted will be counted. After the block's
      # execution completes, the assertion will pass if the count matches.
      #
      #     assert_notifications_count("post.submitted", 1) do
      #       post.submit(title: "Cool Post") # => emits matching notification
      #     end
      #
      def assert_notifications_count(pattern, count, &block)
        actual_count = capture_notifications(pattern, &block).count
        assert_equal(count, actual_count, "Expected #{count} instead of #{actual_count} notifications for #{pattern}")
      end

      # Assert no notifications were emitted for a given +pattern+.
      #
      # You can assert no notifications were emitted by passing a pattern, which accepts
      # either a string or regexp, and a block. While the block is executed, if no
      # matching notifications are emitted, the assertion will pass.
      #
      #     assert_no_notifications("post.submitted") do
      #       post.destroy # => emits non-matching notification
      #     end
      #
      def assert_no_notifications(pattern = nil, &block)
        notifications = capture_notifications(pattern, &block)
        error_message = if pattern
          "Expected no notifications for #{pattern} but found #{notifications.size}"
        else
          "Expected no notifications but found #{notifications.size}"
        end
        assert_empty(notifications, error_message)
      end

      # Capture emitted notifications, optionally filtered by a +pattern+.
      #
      # You can capture emitted notifications, optionally filtered by a pattern,
      # which accepts either a string or regexp, and a block.
      #
      #     notifications = capture_notifications("post.submitted") do
      #       post.submit(title: "Cool Post") # => emits matching notification
      #     end
      #
      def capture_notifications(pattern = nil, &block)
        notifications = []
        ActiveSupport::Notifications.subscribed(->(n) { notifications << n }, pattern, &block)
        notifications
      end
    end
  end
end
