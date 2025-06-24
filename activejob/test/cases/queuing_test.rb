# frozen_string_literal: true

require "helper"
require "jobs/hello_job"
require "jobs/enqueue_error_job"
require "jobs/multiple_kwargs_job"
require "active_support/core_ext/numeric/time"
require "minitest/mock"

class QueuingTest < ActiveSupport::TestCase
  setup do
    JobBuffer.clear
  end

  test "run queued job" do
    HelloJob.perform_later
    assert_equal "David says hello", JobBuffer.last_value
  end

  test "run queued job with arguments" do
    HelloJob.perform_later "Jamie"
    assert_equal "Jamie says hello", JobBuffer.last_value
  end

  test "run queued job later" do
    result = HelloJob.set(wait_until: 1.second.ago).perform_later "Jamie"
    assert result
  rescue NotImplementedError
    pass
  end

  test "job returned by enqueue has the arguments available" do
    job = HelloJob.perform_later "Jamie"
    assert_equal [ "Jamie" ], job.arguments
  end

  test "job returned by perform_at has the timestamp available" do
    job = HelloJob.set(wait_until: Time.utc(2014, 1, 1)).perform_later
    assert_equal Time.utc(2014, 1, 1), job.scheduled_at
  rescue NotImplementedError
    pass
  end

  test "job is yielded to block after enqueue with successfully_enqueued property set" do
    HelloJob.perform_later "John" do |job|
      assert_equal "John says hello", JobBuffer.last_value
      assert_equal [ "John" ], job.arguments
      assert_equal true, job.successfully_enqueued?
      assert_nil job.enqueue_error
    end
  end

  test "configured job is yielded to block after enqueue with successfully_enqueued property set" do
    HelloJob.set(queue: :some_queue).perform_later "John" do |job|
      assert_equal "John says hello", JobBuffer.last_value
      assert_equal [ "John" ], job.arguments
      assert_equal "some_queue", job.queue_name
      assert_equal true, job.successfully_enqueued?
    end
  end

  test "when enqueuing raises an EnqueueError job is yielded to block with error set on job" do
    EnqueueErrorJob.perform_later do |job|
      assert_equal false, job.successfully_enqueued?
      assert_equal ActiveJob::EnqueueError, job.enqueue_error.class
    end
  end

  test "run multiple queued jobs" do
    ActiveJob.perform_all_later(HelloJob.new("Jamie"), HelloJob.new("John"))
    assert_equal ["Jamie says hello", "John says hello"], JobBuffer.values.sort
  end

  test "run multiple queued jobs passed as array" do
    ActiveJob.perform_all_later([HelloJob.new("Jamie"), HelloJob.new("John")])
    assert_equal ["Jamie says hello", "John says hello"], JobBuffer.values.sort
  end

  test "run multiple queued jobs of different classes" do
    ActiveJob.perform_all_later([HelloJob.new("Jamie"), MultipleKwargsJob.new(argument1: "John", argument2: 42)])
    assert_equal ["Jamie says hello", "Job with argument1: John, argument2: 42"], JobBuffer.values.sort
  end

  test "perform_all_later enqueues jobs with schedules" do
    scheduled_job_1 = HelloJob.new("Scheduled 2014")
    scheduled_job_1.set(wait_until: Time.utc(2014, 1, 1))

    scheduled_job_2 = HelloJob.new("Scheduled 2015")
    scheduled_job_2.scheduled_at = Time.utc(2015, 1, 1)

    ActiveJob.perform_all_later(scheduled_job_1, scheduled_job_2)
    assert_equal ["Scheduled 2014 says hello", "Scheduled 2015 says hello"], JobBuffer.values.sort
  rescue NotImplementedError
    pass
  end

  test "perform_all_later instrumentation" do
    jobs = HelloJob.new("Jamie"), HelloJob.new("John")

    notification = assert_notification("enqueue_all.active_job", jobs:, enqueued_count: 2) do
      ActiveJob.perform_all_later(jobs)
    end

    assert notification.payload[:adapter]
  end
end
