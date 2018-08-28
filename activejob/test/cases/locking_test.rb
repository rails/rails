# frozen_string_literal: true

require "helper"
require "jobs/locking_job"
require "json"

class LockingTest < ActiveJob::TestCase
  setup do
    JobBuffer.clear
  end

  test "only enqueues a single job for a given key" do
    LockingJob.perform_later
    LockingJob.perform_later
    LockingJob.perform_later
    assert_equal ["Job enqueued with key: raising_false"], JobBuffer.values
  end

  test "the lock key is cleared after a succssful run" do
    perform_enqueued_jobs do
      LockingJob.perform_later
      assert_equal ["Job enqueued with key: raising_false"], JobBuffer.values

      LockingJob.perform_later
      assert_equal [
        "Job enqueued with key: raising_false",
        "Job enqueued with key: raising_false"
      ], JobBuffer.values

      LockingJob.perform_later
      assert_equal [
        "Job enqueued with key: raising_false",
        "Job enqueued with key: raising_false",
        "Job enqueued with key: raising_false"
      ], JobBuffer.values
    end
  end

  test "locks expire after the configured amount of time" do
    travel_to Time.now
    LockingJob.perform_later

    travel_to Time.now + 1.hour + 2
    LockingJob.perform_later

    travel_to Time.now + 1.hour + 2
    LockingJob.perform_later

    assert_equal [
      "Job enqueued with key: raising_false",
      "Job enqueued with key: raising_false",
      "Job enqueued with key: raising_false"
    ], JobBuffer.values
  end

  test "locking continues to work on retry" do
    perform_enqueued_jobs do
      LockingJob.perform_later(raising: true)
      assert_equal [
        "Job enqueued with key: raising_true",
        "Job enqueued with key: raising_true",
        "Job enqueued with key: raising_true",
        "Job enqueued with key: raising_true",
        "Job enqueued with key: raising_true"
      ], JobBuffer.values
    end
  end

  test "the lock_key is part of the serialized job data" do
    job = LockingJob.new
    key = job.lock_key

    serialized = job.serialize
    assert_equal key, serialized["lock_key"]

    key += "2"
    serialized["lock_key"] = key

    payload = JSON.dump(serialized)
    job2 = LockingJob.deserialize(JSON.load(payload))
    assert_equal key, job2.lock_key
  end
end
