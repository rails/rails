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

  test "the lock key is cleared after a successful run" do
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

  test "the concurrency strategy information is part of the serialized job data" do
    job = ConcurrencyJob.new("raising" => true)

    serialized = job.serialize
    assert_equal 1, serialized["concurrency"].size

    concurrency_strategy = serialized["concurrency"][0]
    assert_equal ActiveJob::Concurrency::Strategy::Exclusive.name, concurrency_strategy["strategy"]
    assert_equal 1, concurrency_strategy["limit"]
    assert_equal ["raising"], concurrency_strategy["keys"]
    assert_equal ActiveJob::Concurrency::DEFAULT_TIMEOUT, concurrency_strategy["timeout"]
  end

  test "job with multiple concurrency strategies stores concurrency information as part of the serialized job data" do
    job = MultipleConcurrencyStrategiesJob.new("resource_id" => 1)

    serialized = job.serialize
    assert_equal 2, serialized["concurrency"].size

    first_concurrency_strategy = serialized["concurrency"][0]
    assert_equal ActiveJob::Concurrency::Strategy::Enqueue.name, first_concurrency_strategy["strategy"]
    assert_equal 2, first_concurrency_strategy["limit"]
    assert_equal ["resource_id"], first_concurrency_strategy["keys"]
    assert_equal ActiveJob::Concurrency::DEFAULT_TIMEOUT, first_concurrency_strategy["timeout"]

    second_concurrency_strategy = serialized["concurrency"][1]
    assert_equal ActiveJob::Concurrency::Strategy::Perform.name, second_concurrency_strategy["strategy"]
    assert_equal 1, second_concurrency_strategy["limit"]
    assert_equal ["resource_id"], second_concurrency_strategy["keys"]
    assert_equal ActiveJob::Concurrency::DEFAULT_TIMEOUT, second_concurrency_strategy["timeout"]
  end

  test "job with custom concurrency prefix stores concurrency information as part of the serialized job data" do
    job = PrefixConcurrencyJob.new("resource_id" => 1)

    serialized = job.serialize
    assert_equal 1, serialized["concurrency"].size

    concurrency_strategy = serialized["concurrency"][0]
    assert_equal ActiveJob::Concurrency::Strategy::Enqueue.name, concurrency_strategy["strategy"]
    assert_equal 1, concurrency_strategy["limit"]
    assert_equal ["resource_id"], concurrency_strategy["keys"]
    assert_equal "my_job", concurrency_strategy["prefix"]
    assert_equal ActiveJob::Concurrency::DEFAULT_TIMEOUT, concurrency_strategy["timeout"]
  end

  test "concurrency build the correct key" do
    job = ConcurrencyJob.new("raising" => true)

    assert_equal "ConcurrencyJob:true", job.concurrency_strategies[0].build_key(job)
  end

  test "concurrency build the correct key with arguments" do
    job = ConcurrencyJob.new()

    assert_equal "ConcurrencyJob:", job.concurrency_strategies[0].build_key(job)
  end

  test "concurrency build the correct key with prefix" do
    job = PrefixConcurrencyJob.new("resource_id" => 23)

    assert_equal "my_job:23", job.concurrency_strategies[0].build_key(job)
  end
end
