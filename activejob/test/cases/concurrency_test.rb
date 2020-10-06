# frozen_string_literal: true

require "helper"
require "jobs/concurrency_job"
require "json"

class ConcurrencyTest < ActiveJob::TestCase
  setup do
    JobBuffer.clear
  end

  test "only enqueues a single job for a given key" do
    ConcurrencyJob.perform_later("raising" => false)
    ConcurrencyJob.perform_later("raising" => false)
    ConcurrencyJob.perform_later("raising" => false)
    assert_equal ["Job enqueued with key: ConcurrencyJob:false"], JobBuffer.values
  end

  test "the lock key is cleared after a succssful run" do
    perform_enqueued_jobs do
      ConcurrencyJob.perform_later("raising" => false)
      assert_equal ["Job enqueued with key: ConcurrencyJob:false"], JobBuffer.values

      ConcurrencyJob.perform_later("raising" => false)
      assert_equal [
        "Job enqueued with key: ConcurrencyJob:false",
        "Job enqueued with key: ConcurrencyJob:false"
      ], JobBuffer.values

      ConcurrencyJob.perform_later("raising" => false)
      assert_equal [
        "Job enqueued with key: ConcurrencyJob:false",
        "Job enqueued with key: ConcurrencyJob:false",
        "Job enqueued with key: ConcurrencyJob:false"
      ], JobBuffer.values
    end
  end

  test "the lock_key is part of the serialized job data" do
    job = ConcurrencyJob.new("raising" => true)
    key = job.concurrency_key

    serialized = job.serialize
    assert_equal key, serialized["concurrency_key"]
  end
end
