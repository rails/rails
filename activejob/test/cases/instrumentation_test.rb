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
    events = subscribed(/perform.*\.active_job/) { HelloJob.perform_now("World!") }
    assert_equal 2, events.size
    assert_equal "perform_start.active_job", events[0].first
    assert_equal "perform.active_job", events[1].first
  end

  test "perform_later emits an enqueue event" do
    events = subscribed("enqueue.active_job") { HelloJob.perform_later("World!") }
    assert_equal 1, events.size
  end

  test "retry emits an enqueue retry event" do
    events = subscribed("enqueue_retry.active_job") do
      perform_enqueued_jobs { RetryJob.perform_later("DefaultsError", 2) }
    end
    assert_equal 1, events.size
  end

  test "retry exhaustion emits a retry_stopped event" do
    events = subscribed("retry_stopped.active_job") do
      perform_enqueued_jobs { RetryJob.perform_later("CustomCatchError", 6) }
    end
    assert_equal 1, events.size
  end

  test "discard emits a discard event" do
    events = subscribed("discard.active_job") do
      perform_enqueued_jobs { RetryJob.perform_later("DiscardableError", 2) }
    end
    assert_equal 1, events.size
  end

  def subscribed(name, &block)
    [].tap do |events|
      ActiveSupport::Notifications.subscribed(-> (*args) { events << args }, name, &block)
    end
  end
end
