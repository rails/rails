# frozen_string_literal: true

require "helper"
require "jobs/hello_job"
require "jobs/retry_job"
require "jobs/after_discard_retry_job"

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

  test "job is removed from the execution context after perform_now" do
    HelloJob.perform_now("World!")
    assert_nil ActiveSupport::ExecutionContext.to_h[:job]
  end

  test "job is in the execution context when discard_on reports an error" do
    job = AfterDiscardRetryJob.new("AfterDiscardRetryJob::ReportedError", 2)

    report = assert_error_reported(AfterDiscardRetryJob::ReportedError) { job.perform_now }

    assert_equal job.job_id, report.context[:job]&.job_id
    assert_nil ActiveSupport::ExecutionContext.to_h[:job]
  end
end
