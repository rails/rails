# frozen_string_literal: true

require "helper"
require "jobs/hello_job"
require "jobs/retry_job"

class InstrumentationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    JobBuffer.clear
  end

  test "perform_now emits perform events" do
    events = capture_notifications(/perform.*\.active_job/) { HelloJob.perform_now("World!") }

    assert_equal 2, events.size
    assert_equal "perform_start.active_job", events[0].name
    assert_equal "perform.active_job", events[1].name
  end

  test "perform_later emits an enqueue event" do
    assert_notifications_count("enqueue.active_job", 1) { HelloJob.perform_later("World!") }
  end

  unless adapter_is?(:inline, :sneakers)
    test "retry emits an enqueue retry event" do
      assert_notifications_count("enqueue_retry.active_job", 1) { RetryJob.perform_later("DefaultsError", 2) }
    end

    test "retry exhaustion emits a retry_stopped event" do
      assert_notifications_count("retry_stopped.active_job", 1) { RetryJob.perform_later("CustomCatchError", 6) }
    end
  end

  test "discard emits a discard event" do
    assert_notifications_count("discard.active_job", 1) { RetryJob.perform_later("DiscardableError", 6) }
  end
end
