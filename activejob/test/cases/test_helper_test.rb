# frozen_string_literal: true

require "helper"
require "active_support/core_ext/time"
require "active_support/core_ext/date"
require "jobs/hello_job"
require "jobs/logging_job"
require "jobs/nested_job"
require "jobs/rescue_job"
require "jobs/inherited_job"
require "models/person"

class EnqueuedJobsTest < ActiveJob::TestCase
  def test_assert_enqueued_jobs
    assert_nothing_raised do
      assert_enqueued_jobs 1 do
        HelloJob.perform_later("david")
      end
    end
  end

  def test_repeated_enqueued_jobs_calls
    assert_nothing_raised do
      assert_enqueued_jobs 1 do
        HelloJob.perform_later("abdelkader")
      end
    end

    assert_nothing_raised do
      assert_enqueued_jobs 2 do
        HelloJob.perform_later("sean")
        HelloJob.perform_later("yves")
      end
    end
  end

  def test_assert_enqueued_jobs_message
    HelloJob.perform_later("sean")
    e = assert_raises Minitest::Assertion do
      assert_enqueued_jobs 2 do
        HelloJob.perform_later("sean")
      end
    end
    assert_match "Expected: 2", e.message
    assert_match "Actual: 1", e.message
  end

  def test_assert_enqueued_jobs_with_no_block
    assert_nothing_raised do
      HelloJob.perform_later("rafael")
      assert_enqueued_jobs 1
    end

    assert_nothing_raised do
      HelloJob.perform_later("aaron")
      HelloJob.perform_later("matthew")
      assert_enqueued_jobs 3
    end
  end

  def test_assert_no_enqueued_jobs_with_no_block
    assert_nothing_raised do
      assert_no_enqueued_jobs
    end
  end

  def test_assert_no_enqueued_jobs
    assert_nothing_raised do
      assert_no_enqueued_jobs do
        HelloJob.perform_now
      end
    end
  end

  def test_assert_enqueued_jobs_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 2 do
        HelloJob.perform_later("xavier")
      end
    end

    assert_match(/2 .* but 1/, error.message)
  end

  def test_assert_enqueued_jobs_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 1 do
        HelloJob.perform_later("cristian")
        HelloJob.perform_later("guillermo")
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_no_enqueued_jobs_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_jobs do
        HelloJob.perform_later("jeremy")
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_option
    assert_nothing_raised do
      assert_enqueued_jobs 1, only: HelloJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_enqueued_jobs_with_except_option
    assert_nothing_raised do
      assert_enqueued_jobs 1, except: LoggingJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_enqueued_jobs_with_only_and_except_option
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 1, only: HelloJob, except: HelloJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_and_queue_option
    assert_nothing_raised do
      assert_enqueued_jobs 1, only: HelloJob, queue: :some_queue do
        HelloJob.set(queue: :some_queue).perform_later
        HelloJob.set(queue: :other_queue).perform_later
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_enqueued_jobs_with_except_and_queue_option
    assert_nothing_raised do
      assert_enqueued_jobs 1, except: LoggingJob, queue: :some_queue do
        HelloJob.set(queue: :some_queue).perform_later
        HelloJob.set(queue: :other_queue).perform_later
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_enqueued_jobs_with_only_and_except_and_queue_option
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 1, only: HelloJob, except: HelloJob, queue: :some_queue do
        HelloJob.set(queue: :some_queue).perform_later
        HelloJob.set(queue: :other_queue).perform_later
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_enqueued_jobs_with_queue_option
    assert_nothing_raised do
      assert_enqueued_jobs 2, queue: :default do
        HelloJob.perform_later
        LoggingJob.perform_later
        HelloJob.set(queue: :other_queue).perform_later
        LoggingJob.set(queue: :other_queue).perform_later
      end
    end
  end

  def test_assert_enqueued_jobs_with_only_option_and_none_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 1, only: HelloJob do
        LoggingJob.perform_later
      end
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_enqueued_jobs_with_except_option_and_none_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 1, except: LoggingJob do
        LoggingJob.perform_later
      end
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_and_except_option_and_none_sent
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 1, only: HelloJob, except: HelloJob do
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_option_and_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 5, only: HelloJob do
        HelloJob.perform_later("jeremy")
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/5 .* but 1/, error.message)
  end

  def test_assert_enqueued_jobs_with_except_option_and_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 5, except: LoggingJob do
        HelloJob.perform_later("jeremy")
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/5 .* but 1/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_and_except_option_and_too_few_sent
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 5, only: HelloJob, except: HelloJob do
        HelloJob.perform_later("jeremy")
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_option_and_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 1, only: HelloJob do
        2.times { HelloJob.perform_later("jeremy") }
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_enqueued_jobs_with_except_option_and_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 1, except: LoggingJob do
        2.times { HelloJob.perform_later("jeremy") }
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_and_except_option_and_too_many_sent
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 1, only: HelloJob, except: HelloJob do
        2.times { HelloJob.perform_later("jeremy") }
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_option_as_array
    assert_nothing_raised do
      assert_enqueued_jobs 2, only: [HelloJob, LoggingJob] do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later("stewie")
        RescueJob.perform_later("david")
      end
    end
  end

  def test_assert_enqueued_jobs_with_except_option_as_array
    assert_nothing_raised do
      assert_enqueued_jobs 1, except: [HelloJob, LoggingJob] do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later("stewie")
        RescueJob.perform_later("david")
      end
    end
  end

  def test_assert_enqueued_jobs_with_only_and_except_option_as_array
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 2, only: [HelloJob, LoggingJob], except: [HelloJob, LoggingJob] do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later("stewie")
        RescueJob.perform_later("david")
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_only_option
    assert_nothing_raised do
      assert_no_enqueued_jobs only: HelloJob do
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_no_enqueued_jobs_with_except_option
    assert_nothing_raised do
      assert_no_enqueued_jobs except: LoggingJob do
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_no_enqueued_jobs_with_only_and_except_option
    error = assert_raise ArgumentError do
      assert_no_enqueued_jobs only: HelloJob, except: HelloJob do
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_only_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_jobs only: HelloJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_except_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_jobs except: LoggingJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_only_and_except_option_failure
    error = assert_raise ArgumentError do
      assert_no_enqueued_jobs only: HelloJob, except: HelloJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_only_option_as_array
    assert_nothing_raised do
      assert_no_enqueued_jobs only: [HelloJob, RescueJob] do
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_no_enqueued_jobs_with_except_option_as_array
    assert_nothing_raised do
      assert_no_enqueued_jobs except: [HelloJob, RescueJob] do
        HelloJob.perform_later
        RescueJob.perform_later
      end
    end
  end

  def test_assert_no_enqueued_jobs_with_only_and_except_option_as_array
    error = assert_raise ArgumentError do
      assert_no_enqueued_jobs only: [HelloJob, RescueJob], except: [HelloJob, RescueJob] do
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_enqueued_job
    assert_enqueued_with(job: LoggingJob, queue: "default") do
      LoggingJob.set(wait_until: Date.tomorrow.noon).perform_later
    end
  end

  def test_assert_enqueued_job_returns
    job = assert_enqueued_with(job: LoggingJob) do
      LoggingJob.set(wait_until: 5.minutes.from_now).perform_later(1, 2, 3)
    end

    assert_instance_of LoggingJob, job
    assert_in_delta 5.minutes.from_now, job.scheduled_at, 1
    assert_equal "default", job.queue_name
    assert_equal [1, 2, 3], job.arguments
  end

  def test_assert_enqueued_job_failure
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: LoggingJob, queue: "default") do
        NestedJob.perform_later
      end
    end

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: NestedJob, queue: "low") do
        NestedJob.perform_later
      end
    end

    assert_equal 'No enqueued job found with {:job=>NestedJob, :queue=>"low"}', error.message
  end

  def test_assert_enqueued_job_args
    assert_raise ArgumentError do
      assert_enqueued_with(class: LoggingJob) do
        NestedJob.set(wait_until: Date.tomorrow.noon).perform_later
      end
    end
  end

  def test_assert_enqueued_job_with_at_option
    assert_enqueued_with(job: HelloJob, at: Date.tomorrow.noon) do
      HelloJob.set(wait_until: Date.tomorrow.noon).perform_later
    end
  end

  def test_assert_enqueued_job_with_global_id_args
    ricardo = Person.new(9)
    assert_enqueued_with(job: HelloJob, args: [ricardo]) do
      HelloJob.perform_later(ricardo)
    end
  end

  def test_assert_enqueued_job_failure_with_global_id_args
    ricardo = Person.new(9)
    wilma = Person.new(11)
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: HelloJob, args: [wilma]) do
        HelloJob.perform_later(ricardo)
      end
    end

    assert_equal "No enqueued job found with {:job=>HelloJob, :args=>[#{wilma.inspect}]}", error.message
  end

  def test_assert_enqueued_job_does_not_change_jobs_count
    HelloJob.perform_later
    assert_enqueued_with(job: HelloJob) do
      HelloJob.perform_later
    end

    assert_equal 2, queue_adapter.enqueued_jobs.count
  end
end

class PerformedJobsTest < ActiveJob::TestCase
  def test_performed_enqueue_jobs_with_only_option_doesnt_leak_outside_the_block
    assert_nil queue_adapter.filter
    perform_enqueued_jobs only: HelloJob do
      assert_equal HelloJob, queue_adapter.filter
    end
    assert_nil queue_adapter.filter
  end

  def test_performed_enqueue_jobs_with_except_option_doesnt_leak_outside_the_block
    assert_nil queue_adapter.reject
    perform_enqueued_jobs except: HelloJob do
      assert_equal HelloJob, queue_adapter.reject
    end
    assert_nil queue_adapter.reject
  end

  def test_assert_performed_jobs
    assert_nothing_raised do
      assert_performed_jobs 1 do
        HelloJob.perform_later("david")
      end
    end
  end

  def test_repeated_performed_jobs_calls
    assert_nothing_raised do
      assert_performed_jobs 1 do
        HelloJob.perform_later("abdelkader")
      end
    end

    assert_nothing_raised do
      assert_performed_jobs 2 do
        HelloJob.perform_later("sean")
        HelloJob.perform_later("yves")
      end
    end
  end

  def test_assert_performed_jobs_message
    HelloJob.perform_later("sean")
    e = assert_raises Minitest::Assertion do
      assert_performed_jobs 2 do
        HelloJob.perform_later("sean")
      end
    end
    assert_match "Expected: 2", e.message
    assert_match "Actual: 1", e.message
  end

  def test_assert_performed_jobs_with_no_block
    assert_nothing_raised do
      perform_enqueued_jobs do
        HelloJob.perform_later("rafael")
      end
      assert_performed_jobs 1
    end

    assert_nothing_raised do
      perform_enqueued_jobs do
        HelloJob.perform_later("aaron")
        HelloJob.perform_later("matthew")
        assert_performed_jobs 3
      end
    end
  end

  def test_assert_no_performed_jobs_with_no_block
    assert_nothing_raised do
      assert_no_performed_jobs
    end
  end

  def test_assert_no_performed_jobs
    assert_nothing_raised do
      assert_no_performed_jobs do
        # empty block won't perform jobs
      end
    end
  end

  def test_assert_performed_jobs_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 2 do
        HelloJob.perform_later("xavier")
      end
    end

    assert_match(/2 .* but 1/, error.message)
  end

  def test_assert_performed_jobs_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1 do
        HelloJob.perform_later("cristian")
        HelloJob.perform_later("guillermo")
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_no_performed_jobs_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs do
        HelloJob.perform_later("jeremy")
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_performed_jobs_with_only_option
    assert_nothing_raised do
      assert_performed_jobs 1, only: HelloJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_performed_jobs_with_except_option
    assert_nothing_raised do
      assert_performed_jobs 1, except: LoggingJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_performed_jobs_with_only_and_except_option
    error = assert_raise ArgumentError do
      assert_performed_jobs 1, only: HelloJob, except: HelloJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_performed_jobs_with_only_option_as_array
    assert_nothing_raised do
      assert_performed_jobs 2, only: [HelloJob, LoggingJob] do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later("stewie")
        RescueJob.perform_later("david")
      end
    end
  end

  def test_assert_performed_jobs_with_except_option_as_array
    assert_nothing_raised do
      assert_performed_jobs 1, except: [LoggingJob, RescueJob] do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later("stewie")
        RescueJob.perform_later("david")
      end
    end
  end

  def test_assert_performed_jobs_with_only_and_except_option_as_array
    error = assert_raise ArgumentError do
      assert_performed_jobs 2, only: [HelloJob, LoggingJob], except: [HelloJob, LoggingJob] do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later("stewie")
        RescueJob.perform_later("david")
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_performed_jobs_with_only_option_and_none_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, only: HelloJob do
        LoggingJob.perform_later
      end
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_performed_jobs_with_except_option_and_none_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, except: LoggingJob do
        LoggingJob.perform_later
      end
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_performed_jobs_with_only_and_except_option_and_none_sent
    error = assert_raise ArgumentError do
      assert_performed_jobs 1, only: HelloJob, except: HelloJob do
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_performed_jobs_with_only_option_and_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 5, only: HelloJob do
        HelloJob.perform_later("jeremy")
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/5 .* but 1/, error.message)
  end

  def test_assert_performed_jobs_with_except_option_and_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 5, except: LoggingJob do
        HelloJob.perform_later("jeremy")
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/5 .* but 1/, error.message)
  end

  def test_assert_performed_jobs_with_only_and_except_option_and_too_few_sent
    error = assert_raise ArgumentError do
      assert_performed_jobs 5, only: HelloJob, except: HelloJob do
        HelloJob.perform_later("jeremy")
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_performed_jobs_with_only_option_and_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, only: HelloJob do
        2.times { HelloJob.perform_later("jeremy") }
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_performed_jobs_with_except_option_and_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, except: LoggingJob do
        2.times { HelloJob.perform_later("jeremy") }
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_performed_jobs_with_only_and_except_option_and_too_many_sent
    error = assert_raise ArgumentError do
      assert_performed_jobs 1, only: HelloJob, except: HelloJob do
        2.times { HelloJob.perform_later("jeremy") }
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_no_performed_jobs_with_only_option
    assert_nothing_raised do
      assert_no_performed_jobs only: HelloJob do
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_no_performed_jobs_with_except_option
    assert_nothing_raised do
      assert_no_performed_jobs except: LoggingJob do
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_no_performed_jobs_with_only_and_except_option
    error = assert_raise ArgumentError do
      assert_no_performed_jobs only: HelloJob, except: HelloJob do
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_no_performed_jobs_with_only_option_as_array
    assert_nothing_raised do
      assert_no_performed_jobs only: [HelloJob, RescueJob] do
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_no_performed_jobs_with_except_option_as_array
    assert_nothing_raised do
      assert_no_performed_jobs except: [HelloJob, RescueJob] do
        HelloJob.perform_later
        RescueJob.perform_later
      end
    end
  end

  def test_assert_no_performed_jobs_with_only_and_except_option_as_array
    error = assert_raise ArgumentError do
      assert_no_performed_jobs only: [HelloJob, RescueJob], except: [HelloJob, RescueJob] do
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_no_performed_jobs_with_only_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs only: HelloJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_with_except_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs except: LoggingJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_with_only_and_except_option_failure
    error = assert_raise ArgumentError do
      assert_no_performed_jobs only: HelloJob, except: HelloJob do
        HelloJob.perform_later("jeremy")
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_performed_job
    assert_performed_with(job: NestedJob, queue: "default") do
      NestedJob.perform_later
    end
  end

  def test_assert_performed_job_returns
    job = assert_performed_with(job: NestedJob, queue: "default") do
      NestedJob.perform_later
    end

    assert_instance_of NestedJob, job
    assert_nil job.scheduled_at
    assert_equal [], job.arguments
    assert_equal "default", job.queue_name
  end

  def test_assert_performed_job_failure
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: LoggingJob) do
        HelloJob.perform_later
      end
    end

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, queue: "low") do
        HelloJob.set(queue: "important").perform_later
      end
    end
  end

  def test_assert_performed_job_with_at_option
    assert_performed_with(job: HelloJob, at: Date.tomorrow.noon) do
      HelloJob.set(wait_until: Date.tomorrow.noon).perform_later
    end

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, at: Date.today.noon) do
        HelloJob.set(wait_until: Date.tomorrow.noon).perform_later
      end
    end
  end

  def test_assert_performed_job_with_global_id_args
    ricardo = Person.new(9)
    assert_performed_with(job: HelloJob, args: [ricardo]) do
      HelloJob.perform_later(ricardo)
    end
  end

  def test_assert_performed_job_failure_with_global_id_args
    ricardo = Person.new(9)
    wilma = Person.new(11)
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, args: [wilma]) do
        HelloJob.perform_later(ricardo)
      end
    end

    assert_equal "No performed job found with {:job=>HelloJob, :args=>[#{wilma.inspect}]}", error.message
  end

  def test_assert_performed_job_does_not_change_jobs_count
    assert_performed_with(job: HelloJob) do
      HelloJob.perform_later
    end

    assert_performed_with(job: HelloJob) do
      HelloJob.perform_later
    end

    assert_equal 2, queue_adapter.performed_jobs.count
  end
end

class OverrideQueueAdapterTest < ActiveJob::TestCase
  class CustomQueueAdapter < ActiveJob::QueueAdapters::TestAdapter; end

  def queue_adapter_for_test
    CustomQueueAdapter.new
  end

  def test_assert_job_has_custom_queue_adapter_set
    assert_instance_of CustomQueueAdapter, HelloJob.queue_adapter
  end
end

class InheritedJobTest < ActiveJob::TestCase
  def test_queue_adapter_is_test_adapter
    assert_instance_of ActiveJob::QueueAdapters::TestAdapter, InheritedJob.queue_adapter
  end
end

class QueueAdapterJobTest < ActiveJob::TestCase
  def before_setup
    @original_autoload_paths = ActiveSupport::Dependencies.autoload_paths
    ActiveSupport::Dependencies.autoload_paths = %w(test/jobs)
    super
  end

  def after_teardown
    ActiveSupport::Dependencies.autoload_paths = @original_autoload_paths
    super
  end

  def test_queue_adapter_is_test_adapter
    assert_instance_of ActiveJob::QueueAdapters::TestAdapter, QueueAdapterJob.queue_adapter
  end
end
