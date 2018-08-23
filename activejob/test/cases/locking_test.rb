# frozen_string_literal: true

require "helper"
require "jobs/locking_job"
require "models/person"

class LockingTest < ActiveJob::TestCase
  setup do
    JobBuffer.clear
  end

  test "only enqueues a single job for a given key" do
    LockingJob.perform_later
    LockingJob.perform_later
    LockingJob.perform_later
    assert_equal ["Job enqueued"], JobBuffer.values
  end

  test "the lock key is cleared after a succssful run" do
    perform_enqueued_jobs do
      LockingJob.perform_later
      assert_equal ["Job enqueued"], JobBuffer.values

      LockingJob.perform_later
      assert_equal ["Job enqueued", "Job enqueued"], JobBuffer.values

      LockingJob.perform_later
      assert_equal ["Job enqueued", "Job enqueued", "Job enqueued"], JobBuffer.values
    end
  end

  test "locks expire after the configured amount of time" do
    travel_to Time.now
    LockingJob.perform_later

    travel_to Time.now + 1.hour + 2
    LockingJob.perform_later

    travel_to Time.now + 1.hour + 2
    LockingJob.perform_later

    assert_equal ["Job enqueued", "Job enqueued", "Job enqueued"], JobBuffer.values
  end
end
