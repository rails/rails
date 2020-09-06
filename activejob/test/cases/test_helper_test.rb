# frozen_string_literal: true

require 'helper'
require 'active_support/core_ext/time'
require 'active_support/core_ext/date'
require 'jobs/hello_job'
require 'jobs/logging_job'
require 'jobs/nested_job'
require 'jobs/rescue_job'
require 'jobs/raising_job'
require 'jobs/inherited_job'
require 'jobs/multiple_kwargs_job'
require 'models/person'

class EnqueuedJobsTest < ActiveJob::TestCase
  def test_assert_enqueued_jobs
    assert_nothing_raised do
      assert_enqueued_jobs 1 do
        HelloJob.perform_later('david')
      end
    end
  end

  def test_repeated_enqueued_jobs_calls
    assert_nothing_raised do
      assert_enqueued_jobs 1 do
        HelloJob.perform_later('abdelkader')
      end
    end

    assert_nothing_raised do
      assert_enqueued_jobs 2 do
        HelloJob.perform_later('sean')
        HelloJob.perform_later('yves')
      end
    end
  end

  def test_assert_enqueued_jobs_message
    HelloJob.perform_later('sean')
    e = assert_raises Minitest::Assertion do
      assert_enqueued_jobs 2 do
        HelloJob.perform_later('sean')
      end
    end
    assert_match 'Expected: 2', e.message
    assert_match 'Actual: 1', e.message
  end

  def test_assert_enqueued_jobs_with_no_block
    assert_nothing_raised do
      HelloJob.perform_later('rafael')
      assert_enqueued_jobs 1
    end

    assert_nothing_raised do
      HelloJob.perform_later('aaron')
      HelloJob.perform_later('matthew')
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
        HelloJob.perform_later('xavier')
      end
    end

    assert_match(/2 .* but 1/, error.message)
  end

  def test_assert_enqueued_jobs_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 1 do
        HelloJob.perform_later('cristian')
        HelloJob.perform_later('guillermo')
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_no_enqueued_jobs_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_jobs do
        HelloJob.perform_later('jeremy')
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_option
    assert_nothing_raised do
      assert_enqueued_jobs 1, only: HelloJob do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_enqueued_jobs_with_only_option_as_proc
    assert_nothing_raised do
      assert_enqueued_jobs(1, only: ->(job) { job.fetch(:job).name == 'HelloJob' }) do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_enqueued_jobs_with_except_option
    assert_nothing_raised do
      assert_enqueued_jobs 1, except: LoggingJob do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_enqueued_jobs_with_except_option_as_proc
    assert_nothing_raised do
      assert_enqueued_jobs(1, except: ->(job) { job.fetch(:job).name == 'LoggingJob' }) do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_enqueued_jobs_with_only_and_except_option
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 1, only: HelloJob, except: HelloJob do
        HelloJob.perform_later('jeremy')
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
        HelloJob.perform_later('jeremy')
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/5 .* but 1/, error.message)
  end

  def test_assert_enqueued_jobs_with_except_option_and_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 5, except: LoggingJob do
        HelloJob.perform_later('jeremy')
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/5 .* but 1/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_and_except_option_and_too_few_sent
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 5, only: HelloJob, except: HelloJob do
        HelloJob.perform_later('jeremy')
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_option_and_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 1, only: HelloJob do
        2.times { HelloJob.perform_later('jeremy') }
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_enqueued_jobs_with_except_option_and_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 1, except: LoggingJob do
        2.times { HelloJob.perform_later('jeremy') }
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_and_except_option_and_too_many_sent
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 1, only: HelloJob, except: HelloJob do
        2.times { HelloJob.perform_later('jeremy') }
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_enqueued_jobs_with_only_option_as_array
    assert_nothing_raised do
      assert_enqueued_jobs 2, only: [HelloJob, LoggingJob] do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later('stewie')
        RescueJob.perform_later('david')
      end
    end
  end

  def test_assert_enqueued_jobs_with_except_option_as_array
    assert_nothing_raised do
      assert_enqueued_jobs 1, except: [HelloJob, LoggingJob] do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later('stewie')
        RescueJob.perform_later('david')
      end
    end
  end

  def test_assert_enqueued_jobs_with_only_and_except_option_as_array
    error = assert_raise ArgumentError do
      assert_enqueued_jobs 2, only: [HelloJob, LoggingJob], except: [HelloJob, LoggingJob] do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later('stewie')
        RescueJob.perform_later('david')
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
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_except_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_jobs except: LoggingJob do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_only_and_except_option_failure
    error = assert_raise ArgumentError do
      assert_no_enqueued_jobs only: HelloJob, except: HelloJob do
        HelloJob.perform_later('jeremy')
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

  def test_assert_no_enqueued_jobs_with_queue_option
    assert_nothing_raised do
      assert_no_enqueued_jobs queue: :default do
        HelloJob.set(queue: :other_queue).perform_later
        LoggingJob.set(queue: :other_queue).perform_later
      end
    end
  end

  def test_assert_no_enqueued_jobs_with_queue_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_jobs queue: :other_queue do
        HelloJob.set(queue: :other_queue).perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_only_and_queue_option
    assert_nothing_raised do
      assert_no_enqueued_jobs only: HelloJob, queue: :some_queue do
        HelloJob.set(queue: :other_queue).perform_later
        HelloJob.set(queue: :other_queue).perform_later
        LoggingJob.set(queue: :some_queue).perform_later
      end
    end
  end

  def test_assert_no_enqueued_jobs_with_only_and_queue_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_jobs only: HelloJob, queue: :some_queue do
        HelloJob.set(queue: :other_queue).perform_later
        HelloJob.set(queue: :some_queue).perform_later
        LoggingJob.set(queue: :some_queue).perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_except_and_queue_option
    assert_nothing_raised do
      assert_no_enqueued_jobs except: LoggingJob, queue: :some_queue do
        HelloJob.set(queue: :other_queue).perform_later
        HelloJob.set(queue: :other_queue).perform_later
        LoggingJob.set(queue: :some_queue).perform_later
      end
    end
  end

  def test_assert_no_enqueued_jobs_with_except_and_queue_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_jobs except: LoggingJob, queue: :some_queue do
        HelloJob.set(queue: :other_queue).perform_later
        HelloJob.set(queue: :some_queue).perform_later
        LoggingJob.set(queue: :some_queue).perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_enqueued_jobs_with_only_and_except_and_queue_option
    error = assert_raise ArgumentError do
      assert_no_enqueued_jobs only: HelloJob, except: HelloJob, queue: :some_queue do
        HelloJob.set(queue: :other_queue).perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_enqueued_with
    assert_enqueued_with(job: LoggingJob, queue: 'default') do
      LoggingJob.set(wait_until: Date.tomorrow.noon).perform_later
    end
  end

  def test_assert_enqueued_with_with_no_block
    LoggingJob.set(wait_until: Date.tomorrow.noon).perform_later
    assert_enqueued_with(job: LoggingJob, queue: 'default')
  end

  def test_assert_enqueued_with_returns
    job = assert_enqueued_with(job: LoggingJob) do
      LoggingJob.set(wait_until: 5.minutes.from_now).perform_later(1, 2, 3, keyword: true)
    end

    assert_instance_of LoggingJob, job
    assert_in_delta 5.minutes.from_now, job.scheduled_at, 1
    assert_equal 'default', job.queue_name
    assert_equal [1, 2, 3, { keyword: true }], job.arguments
  end

  def test_assert_enqueued_with_with_no_block_returns
    LoggingJob.set(wait_until: 5.minutes.from_now).perform_later(1, 2, 3, keyword: true)
    job = assert_enqueued_with(job: LoggingJob)

    assert_instance_of LoggingJob, job
    assert_in_delta 5.minutes.from_now, job.scheduled_at, 1
    assert_equal 'default', job.queue_name
    assert_equal [1, 2, 3, { keyword: true }], job.arguments
  end

  def test_assert_enqueued_with_failure
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: LoggingJob, queue: 'default') do
        NestedJob.perform_later
      end
    end

    assert_raise ActiveSupport::TestCase::Assertion do
      LoggingJob.perform_later
      assert_enqueued_with(job: LoggingJob) { }
    end

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: NestedJob, queue: 'low') do
        NestedJob.perform_later
      end
    end

    assert_match(/No enqueued job found with {:job=>NestedJob, :queue=>"low"}/, error.message)
  end

  def test_assert_enqueued_with_with_no_block_failure
    assert_raise ActiveSupport::TestCase::Assertion do
      NestedJob.perform_later
      assert_enqueued_with(job: LoggingJob, queue: 'default')
    end

    error = assert_raise ActiveSupport::TestCase::Assertion do
      NestedJob.perform_later
      assert_enqueued_with(job: NestedJob, queue: 'low')
    end

    assert_match(/No enqueued job found with {:job=>NestedJob, :queue=>"low"}/, error.message)
  end

  def test_assert_enqueued_with_args
    assert_raise ArgumentError do
      assert_enqueued_with(class: LoggingJob) do
        NestedJob.set(wait_until: Date.tomorrow.noon).perform_later
      end
    end
  end

  def test_assert_enqueued_with_supports_matcher_procs
    facets = {
      job: HelloJob,
      args: ['Rails'],
      at: Date.tomorrow.noon,
      queue: 'important',
    }

    facets[:job].set(queue: facets[:queue], wait_until: facets[:at]).perform_later(*facets[:args])

    facets.each do |facet, value|
      matcher = ->(job_value) { job_value == value }
      refuser = ->(job_value) { false }

      assert_enqueued_with(**{ facet => matcher })

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_enqueued_with(**{ facet => refuser })
      end
    end
  end

  def test_assert_enqueued_with_time
    now = Time.now
    args = [{ argument1: [now] }]

    assert_enqueued_with(job: MultipleKwargsJob, args: args) do
      MultipleKwargsJob.perform_later(argument1: [now])
    end
  end

  def test_assert_enqueued_with_date_time
    now = DateTime.now
    args = [{ argument1: [now] }]

    assert_enqueued_with(job: MultipleKwargsJob, args: args) do
      MultipleKwargsJob.perform_later(argument1: [now])
    end
  end

  def test_assert_enqueued_with_time_with_zone
    now = Time.now.in_time_zone('Tokyo')
    args = [{ argument1: [now] }]

    assert_enqueued_with(job: MultipleKwargsJob, args: args) do
      MultipleKwargsJob.perform_later(argument1: [now])
    end
  end

  def test_assert_enqueued_with_with_no_block_args
    assert_raise ArgumentError do
      NestedJob.set(wait_until: Date.tomorrow.noon).perform_later
      assert_enqueued_with(class: LoggingJob)
    end
  end

  def test_assert_enqueued_with_with_at_option
    assert_enqueued_with(job: HelloJob, at: Date.tomorrow.noon) do
      HelloJob.set(wait_until: Date.tomorrow.noon).perform_later
    end
  end

  def test_assert_enqueued_with_with_relative_at_option
    assert_enqueued_with(job: HelloJob, at: 5.minutes.from_now) do
      HelloJob.set(wait: 5.minutes).perform_later
    end
  end

  def test_assert_enqueued_with_with_no_block_with_at_option
    HelloJob.set(wait_until: Date.tomorrow.noon).perform_later
    assert_enqueued_with(job: HelloJob, at: Date.tomorrow.noon)
  end

  def test_assert_enqueued_with_wait_until_with_performed
    assert_enqueued_with(job: LoggingJob) do
      perform_enqueued_jobs(only: HelloJob) do
        HelloJob.set(wait_until: Date.tomorrow.noon).perform_later('david')
        LoggingJob.set(wait_until: Date.tomorrow.noon).perform_later('enqueue')
      end
    end
    assert_enqueued_jobs 1
    assert_performed_jobs 1
  end

  def test_assert_enqueued_with_with_hash_arg
    assert_enqueued_with(job: MultipleKwargsJob, args: [{ argument1: 1, argument2: { a: 1, b: 2 } }]) do
      MultipleKwargsJob.perform_later(argument2: { b: 2, a: 1 }, argument1: 1)
    end
  end

  def test_assert_enqueued_with_with_global_id_args
    ricardo = Person.new(9)
    assert_enqueued_with(job: HelloJob, args: [ricardo]) do
      HelloJob.perform_later(ricardo)
    end
  end

  def test_assert_enqueued_with_with_no_block_with_global_id_args
    ricardo = Person.new(9)
    HelloJob.perform_later(ricardo)
    assert_enqueued_with(job: HelloJob, args: [ricardo])
  end

  def test_assert_enqueued_with_failure_with_global_id_args
    ricardo = Person.new(9)
    wilma = Person.new(11)
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: HelloJob, args: [wilma]) do
        HelloJob.perform_later(ricardo)
      end
    end
    assert_match(/No enqueued job found with {:job=>HelloJob, :args=>\[#{wilma.inspect}\]}/, error.message)
    assert_match(/Potential matches: {.*?:job=>HelloJob, :args=>\[#<Person.* @id=\"9\"\>\], :queue=>\"default\"}/, error.message)
  end

  def test_assert_enqueued_with_failure_with_no_block_with_global_id_args
    ricardo = Person.new(9)
    wilma = Person.new(11)
    error = assert_raise ActiveSupport::TestCase::Assertion do
      HelloJob.perform_later(ricardo)
      assert_enqueued_with(job: HelloJob, args: [wilma])
    end

    assert_match(/No enqueued job found with {:job=>HelloJob, :args=>\[#{wilma.inspect}\]}/, error.message)
    assert_match(/Potential matches: {.*?:job=>HelloJob, :args=>\[#<Person.* @id=\"9\"\>\], :queue=>\"default\"}/, error.message)
  end

  def test_assert_enqueued_with_does_not_change_jobs_count
    HelloJob.perform_later
    assert_enqueued_with(job: HelloJob) do
      HelloJob.perform_later
    end

    assert_equal 2, queue_adapter.enqueued_jobs.count
  end

  def test_assert_enqueued_with_with_no_block_does_not_change_jobs_count
    HelloJob.perform_later
    HelloJob.perform_later
    assert_enqueued_with(job: HelloJob)

    assert_equal 2, queue_adapter.enqueued_jobs.count
  end

  def test_assert_enqueued_jobs_with_performed
    assert_enqueued_with(job: LoggingJob) do
      perform_enqueued_jobs(only: HelloJob) do
        HelloJob.perform_later('david')
        LoggingJob.perform_later('enqueue')
      end
    end
    assert_enqueued_jobs 1
    assert_performed_jobs 1
  end
end

class PerformedJobsTest < ActiveJob::TestCase
  def test_perform_enqueued_jobs_with_only_option_doesnt_leak_outside_the_block
    assert_nil queue_adapter.filter
    perform_enqueued_jobs only: HelloJob do
      assert_equal HelloJob, queue_adapter.filter
    end
    assert_nil queue_adapter.filter
  end

  def test_perform_enqueued_jobs_without_block_with_only_option_doesnt_leak
    perform_enqueued_jobs only: HelloJob

    assert_nil queue_adapter.filter
  end

  def test_perform_enqueued_jobs_with_except_option_doesnt_leak_outside_the_block
    assert_nil queue_adapter.reject
    perform_enqueued_jobs except: HelloJob do
      assert_equal HelloJob, queue_adapter.reject
    end
    assert_nil queue_adapter.reject
  end

  def test_perform_enqueued_jobs_without_block_with_except_option_doesnt_leak
    perform_enqueued_jobs except: HelloJob

    assert_nil queue_adapter.reject
  end

  def test_perform_enqueued_jobs_with_queue_option_doesnt_leak_outside_the_block
    assert_nil queue_adapter.queue
    perform_enqueued_jobs queue: :some_queue do
      assert_equal :some_queue, queue_adapter.queue
    end
    assert_nil queue_adapter.queue
  end

  def test_perform_enqueued_jobs_without_block_with_queue_option_doesnt_leak
    perform_enqueued_jobs queue: :some_queue

    assert_nil queue_adapter.reject
  end

  def test_perform_enqueued_jobs_with_block
    perform_enqueued_jobs do
      HelloJob.perform_later('kevin')
      LoggingJob.perform_later('bogdan')
    end

    assert_performed_jobs 2
  end

  def test_perform_enqueued_jobs_without_block
    HelloJob.perform_later('kevin')
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs

    assert_performed_jobs 2
  end

  def test_perform_enqueued_jobs_with_block_with_only_option
    perform_enqueued_jobs only: LoggingJob do
      HelloJob.perform_later('kevin')
      LoggingJob.perform_later('bogdan')
    end

    assert_performed_jobs 1
    assert_performed_jobs 1, only: LoggingJob
  end

  def test_perform_enqueued_jobs_without_block_with_only_option
    HelloJob.perform_later('kevin')
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs only: LoggingJob

    assert_performed_jobs 1
    assert_performed_jobs 1, only: LoggingJob
  end

  def test_perform_enqueued_jobs_with_block_with_except_option
    perform_enqueued_jobs except: HelloJob do
      HelloJob.perform_later('kevin')
      LoggingJob.perform_later('bogdan')
    end

    assert_performed_jobs 1
    assert_performed_jobs 1, only: LoggingJob
  end

  def test_perform_enqueued_jobs_without_block_with_except_option
    HelloJob.perform_later('kevin')
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs except: HelloJob

    assert_performed_jobs 1
    assert_performed_jobs 1, only: LoggingJob
  end

  def test_perform_enqueued_jobs_with_block_with_queue_option
    perform_enqueued_jobs queue: :some_queue do
      HelloJob.set(queue: :some_queue).perform_later('kevin')
      HelloJob.set(queue: :other_queue).perform_later('bogdan')
      LoggingJob.perform_later('bogdan')
    end

    assert_performed_jobs 1
    assert_performed_jobs 1, only: HelloJob, queue: :some_queue
  end

  def test_perform_enqueued_jobs_without_block_with_queue_option
    HelloJob.set(queue: :some_queue).perform_later('kevin')
    HelloJob.set(queue: :other_queue).perform_later('bogdan')
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs queue: :some_queue

    assert_performed_jobs 1
    assert_performed_jobs 1, only: HelloJob, queue: :some_queue
  end

  def test_perform_enqueued_jobs_with_block_with_only_and_queue_options
    perform_enqueued_jobs only: HelloJob, queue: :other_queue do
      HelloJob.set(queue: :some_queue).perform_later('kevin')
      HelloJob.set(queue: :other_queue).perform_later('bogdan')
      LoggingJob.set(queue: :other_queue).perform_later('bogdan')
    end

    assert_performed_jobs 1
    assert_performed_jobs 1, only: HelloJob, queue: :other_queue
  end

  def test_perform_enqueued_jobs_without_block_with_only_and_queue_options
    HelloJob.set(queue: :some_queue).perform_later('kevin')
    HelloJob.set(queue: :other_queue).perform_later('bogdan')
    LoggingJob.set(queue: :other_queue).perform_later('bogdan')

    perform_enqueued_jobs only: HelloJob, queue: :other_queue

    assert_performed_jobs 1
    assert_performed_jobs 1, only: HelloJob, queue: :other_queue
  end

  def test_perform_enqueued_jobs_with_block_with_except_and_queue_options
    perform_enqueued_jobs except: HelloJob, queue: :other_queue do
      HelloJob.set(queue: :other_queue).perform_later('kevin')
      LoggingJob.set(queue: :some_queue).perform_later('bogdan')
      LoggingJob.set(queue: :other_queue).perform_later('bogdan')
    end

    assert_performed_jobs 1
    assert_performed_jobs 1, only: LoggingJob, queue: :other_queue
  end

  def test_perform_enqueued_jobs_without_block_with_except_and_queue_options
    HelloJob.set(queue: :other_queue).perform_later('kevin')
    LoggingJob.set(queue: :some_queue).perform_later('bogdan')
    LoggingJob.set(queue: :other_queue).perform_later('bogdan')

    perform_enqueued_jobs except: HelloJob, queue: :other_queue

    assert_performed_jobs 1
    assert_performed_jobs 1, only: LoggingJob, queue: :other_queue
  end

  def test_perform_enqueued_jobs_with_at_with_job_performed_now
    HelloJob.perform_later('kevin')

    perform_enqueued_jobs(at: Time.now)

    assert_performed_jobs 1
  end

  def test_perform_enqueued_jobs_with_at_with_job_wait_in_past
    HelloJob.set(wait_until: Time.now - 100).perform_later('kevin')

    perform_enqueued_jobs(at: Time.now)

    assert_performed_jobs 1
  end

  def test_perform_enqueued_jobs_with_at_with_job_wait_in_future
    HelloJob.set(wait_until: Time.now + 100).perform_later('kevin')

    perform_enqueued_jobs(at: Time.now)

    assert_performed_jobs 0
  end

  def test_perform_enqueued_jobs_block_with_at_with_job_performed_now
    perform_enqueued_jobs(at: Time.now) do
      HelloJob.perform_later('kevin')
    end

    assert_performed_jobs 1
  end

  def test_perform_enqueued_jobs_block_with_at_with_job_wait_in_past
    perform_enqueued_jobs(at: Time.now) do
      HelloJob.set(wait_until: Time.now - 100).perform_later('kevin')
    end

    assert_performed_jobs 1
  end

  def test_perform_enqueued_jobs_block_with_at_with_job_wait_in_future
    perform_enqueued_jobs(at: Time.now) do
      HelloJob.set(wait_until: Time.now + 100).perform_later('kevin')
    end

    assert_performed_jobs 0
  end

  def test_perform_enqueued_jobs_properly_count_job_that_raises
    RaisingJob.perform_later('NotImplementedError')

    assert_raises(NotImplementedError) do
      perform_enqueued_jobs(only: RaisingJob)
    end

    assert_equal(1, performed_jobs.size)
  end

  def test_perform_enqueued_jobs_dont_perform_retries
    RaisingJob.perform_later

    assert_nothing_raised do
      perform_enqueued_jobs(only: RaisingJob)
    end

    assert_equal(1, performed_jobs.size)
    assert_equal(1, enqueued_jobs.size)
  end

  def test_perform_enqueued_jobs_without_block_removes_from_enqueued_jobs
    HelloJob.perform_later('rafael')
    assert_equal(0, performed_jobs.size)
    assert_equal(1, enqueued_jobs.size)
    perform_enqueued_jobs
    assert_equal(1, performed_jobs.size)
    assert_equal(0, enqueued_jobs.size)
  end

  def test_perform_enqueued_jobs_without_block_works_with_other_helpers
    NestedJob.perform_later
    assert_equal(0, performed_jobs.size)
    assert_equal(1, enqueued_jobs.size)
    assert_enqueued_jobs(1) do
      assert_enqueued_with(job: LoggingJob) do
        perform_enqueued_jobs
      end
    end
    assert_equal(1, performed_jobs.size)
    assert_equal(1, enqueued_jobs.size)
  end

  def test_perform_enqueued_jobs_without_block_only_performs_once
    JobBuffer.clear
    RescueJob.perform_later('no exception')
    perform_enqueued_jobs
    perform_enqueued_jobs
    assert_equal(1, JobBuffer.values.size)
  end

  def test_assert_performed_jobs
    assert_nothing_raised do
      assert_performed_jobs 1 do
        HelloJob.perform_later('david')
      end
    end
  end

  def test_repeated_performed_jobs_calls
    assert_nothing_raised do
      assert_performed_jobs 1 do
        HelloJob.perform_later('abdelkader')
      end
    end

    assert_nothing_raised do
      assert_performed_jobs 2 do
        HelloJob.perform_later('sean')
        HelloJob.perform_later('yves')
      end
    end
  end

  def test_assert_performed_jobs_message
    HelloJob.perform_later('sean')
    e = assert_raises Minitest::Assertion do
      assert_performed_jobs 2 do
        HelloJob.perform_later('sean')
      end
    end
    assert_match 'Expected: 2', e.message
    assert_match 'Actual: 1', e.message
  end

  def test_assert_performed_jobs_with_no_block
    assert_nothing_raised do
      perform_enqueued_jobs do
        HelloJob.perform_later('rafael')
      end
      assert_performed_jobs 1
    end

    assert_nothing_raised do
      perform_enqueued_jobs do
        HelloJob.perform_later('aaron')
        HelloJob.perform_later('matthew')
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
        HelloJob.perform_later('xavier')
      end
    end

    assert_match(/2 .* but 1/, error.message)
  end

  def test_assert_performed_jobs_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1 do
        HelloJob.perform_later('cristian')
        HelloJob.perform_later('guillermo')
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_no_performed_jobs_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs do
        HelloJob.perform_later('jeremy')
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_performed_jobs_with_only_option
    assert_nothing_raised do
      assert_performed_jobs 1, only: HelloJob do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_performed_jobs_with_only_option_as_proc
    assert_nothing_raised do
      assert_performed_jobs(1, only: ->(job) { job.is_a?(HelloJob) }) do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later('bogdan')
      end
    end
  end

  def test_assert_performed_jobs_without_block_with_only_option
    HelloJob.perform_later('jeremy')
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs

    assert_performed_jobs 1, only: HelloJob
  end

  def test_assert_performed_jobs_without_block_with_only_option_as_proc
    HelloJob.perform_later('jeremy')
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs

    assert_performed_jobs(1, only: ->(job) { job.fetch(:job).name == 'HelloJob' })
  end

  def test_assert_performed_jobs_without_block_with_only_option_failure
    LoggingJob.perform_later('jeremy')
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, only: HelloJob
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_performed_jobs_with_except_option
    assert_nothing_raised do
      assert_performed_jobs 1, except: LoggingJob do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_performed_jobs_with_except_option_as_proc
    assert_nothing_raised do
      assert_performed_jobs(1, except: ->(job) { job.is_a?(HelloJob) }) do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later('bogdan')
      end
    end
  end

  def test_assert_performed_jobs_without_block_with_except_option
    HelloJob.perform_later('jeremy')
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs

    assert_performed_jobs 1, except: HelloJob
  end

  def test_assert_performed_jobs_without_block_with_except_option_as_proc
    HelloJob.perform_later('jeremy')
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs

    assert_performed_jobs(1, except: ->(job) { job.fetch(:job).name == 'HelloJob' })
  end

  def test_assert_performed_jobs_without_block_with_except_option_failure
    HelloJob.perform_later('jeremy')
    HelloJob.perform_later('bogdan')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, except: HelloJob
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_performed_jobs_with_only_and_except_option
    error = assert_raise ArgumentError do
      assert_performed_jobs 1, only: HelloJob, except: HelloJob do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_performed_jobs_without_block_with_only_and_except_options
    error = assert_raise ArgumentError do
      HelloJob.perform_later('jeremy')
      LoggingJob.perform_later('bogdan')

      perform_enqueued_jobs

      assert_performed_jobs 1, only: HelloJob, except: HelloJob
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_performed_jobs_with_only_option_as_array
    assert_nothing_raised do
      assert_performed_jobs 2, only: [HelloJob, LoggingJob] do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later('stewie')
        RescueJob.perform_later('david')
      end
    end
  end

  def test_assert_performed_jobs_with_except_option_as_array
    assert_nothing_raised do
      assert_performed_jobs 1, except: [LoggingJob, RescueJob] do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later('stewie')
        RescueJob.perform_later('david')
      end
    end
  end

  def test_assert_performed_jobs_with_only_and_except_option_as_array
    error = assert_raise ArgumentError do
      assert_performed_jobs 2, only: [HelloJob, LoggingJob], except: [HelloJob, LoggingJob] do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later('stewie')
        RescueJob.perform_later('david')
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
        HelloJob.perform_later('jeremy')
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/5 .* but 1/, error.message)
  end

  def test_assert_performed_jobs_with_except_option_and_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 5, except: LoggingJob do
        HelloJob.perform_later('jeremy')
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/5 .* but 1/, error.message)
  end

  def test_assert_performed_jobs_with_only_and_except_option_and_too_few_sent
    error = assert_raise ArgumentError do
      assert_performed_jobs 5, only: HelloJob, except: HelloJob do
        HelloJob.perform_later('jeremy')
        4.times { LoggingJob.perform_later }
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_performed_jobs_with_only_option_and_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, only: HelloJob do
        2.times { HelloJob.perform_later('jeremy') }
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_performed_jobs_with_except_option_and_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, except: LoggingJob do
        2.times { HelloJob.perform_later('jeremy') }
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_performed_jobs_with_only_and_except_option_and_too_many_sent
    error = assert_raise ArgumentError do
      assert_performed_jobs 1, only: HelloJob, except: HelloJob do
        2.times { HelloJob.perform_later('jeremy') }
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_performed_jobs_with_queue_option
    assert_performed_jobs 1, queue: :some_queue do
      HelloJob.set(queue: :some_queue).perform_later('jeremy')
      HelloJob.set(queue: :other_queue).perform_later('bogdan')
    end
  end

  def test_assert_performed_jobs_with_queue_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, queue: :some_queue do
        HelloJob.set(queue: :other_queue).perform_later('jeremy')
        HelloJob.set(queue: :other_queue).perform_later('bogdan')
      end
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_performed_jobs_without_block_with_queue_option
    HelloJob.set(queue: :some_queue).perform_later('jeremy')
    HelloJob.set(queue: :other_queue).perform_later('bogdan')

    perform_enqueued_jobs

    assert_performed_jobs 1, queue: :some_queue
  end

  def test_assert_performed_jobs_without_block_with_queue_option_failure
    HelloJob.set(queue: :other_queue).perform_later('jeremy')
    HelloJob.set(queue: :other_queue).perform_later('bogdan')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, queue: :some_queue
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_performed_jobs_with_only_and_queue_options
    assert_performed_jobs 1, only: HelloJob, queue: :some_queue do
      HelloJob.set(queue: :some_queue).perform_later('jeremy')
      HelloJob.set(queue: :other_queue).perform_later('bogdan')
      LoggingJob.set(queue: :some_queue).perform_later('jeremy')
    end
  end

  def test_assert_performed_jobs_with_only_and_queue_options_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, only: HelloJob, queue: :some_queue do
        HelloJob.set(queue: :other_queue).perform_later('jeremy')
        HelloJob.set(queue: :other_queue).perform_later('bogdan')
        LoggingJob.set(queue: :some_queue).perform_later('jeremy')
      end
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_performed_jobs_without_block_with_only_and_queue_options
    HelloJob.set(queue: :some_queue).perform_later('jeremy')
    HelloJob.set(queue: :other_queue).perform_later('bogdan')
    LoggingJob.set(queue: :some_queue).perform_later('jeremy')

    perform_enqueued_jobs

    assert_performed_jobs 1, only: HelloJob, queue: :some_queue
  end

  def test_assert_performed_jobs_without_block_with_only_and_queue_options_failure
    HelloJob.set(queue: :other_queue).perform_later('jeremy')
    HelloJob.set(queue: :other_queue).perform_later('bogdan')
    LoggingJob.set(queue: :some_queue).perform_later('jeremy')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, only: HelloJob, queue: :some_queue
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_performed_jobs_with_except_and_queue_options
    assert_performed_jobs 1, except: HelloJob, queue: :other_queue do
      HelloJob.set(queue: :other_queue).perform_later('jeremy')
      LoggingJob.set(queue: :some_queue).perform_later('bogdan')
      LoggingJob.set(queue: :other_queue).perform_later('jeremy')
    end
  end

  def test_assert_performed_jobs_with_except_and_queue_options_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, except: HelloJob, queue: :other_queue do
        HelloJob.set(queue: :other_queue).perform_later('jeremy')
        LoggingJob.set(queue: :some_queue).perform_later('bogdan')
        LoggingJob.set(queue: :some_queue).perform_later('jeremy')
      end
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_performed_jobs_without_block_with_except_and_queue_options
    HelloJob.set(queue: :other_queue).perform_later('jeremy')
    LoggingJob.set(queue: :some_queue).perform_later('bogdan')
    LoggingJob.set(queue: :other_queue).perform_later('jeremy')

    perform_enqueued_jobs

    assert_performed_jobs 1, except: HelloJob, queue: :other_queue
  end

  def test_assert_performed_jobs_without_block_with_except_and_queue_options_failure
    HelloJob.set(queue: :other_queue).perform_later('jeremy')
    LoggingJob.set(queue: :some_queue).perform_later('bogdan')
    LoggingJob.set(queue: :some_queue).perform_later('jeremy')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1, except: HelloJob, queue: :other_queue
    end

    assert_match(/1 .* but 0/, error.message)
  end

  def test_assert_no_performed_jobs_with_only_option
    assert_nothing_raised do
      assert_no_performed_jobs only: HelloJob do
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_no_performed_jobs_without_block_with_only_option
    LoggingJob.perform_later('bogdan')

    perform_enqueued_jobs

    assert_no_performed_jobs only: HelloJob
  end

  def test_assert_no_performed_jobs_without_block_with_only_option_failure
    HelloJob.perform_later('bogdan')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs only: HelloJob
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_with_except_option
    assert_nothing_raised do
      assert_no_performed_jobs except: LoggingJob do
        LoggingJob.perform_later
      end
    end
  end

  def test_assert_no_performed_jobs_without_block_with_except_option
    HelloJob.perform_later('jeremy')

    perform_enqueued_jobs

    assert_no_performed_jobs except: HelloJob
  end

  def test_assert_no_performed_jobs_without_block_with_except_option_failure
    LoggingJob.perform_later('jeremy')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs except: HelloJob
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_with_only_and_except_option
    error = assert_raise ArgumentError do
      assert_no_performed_jobs only: HelloJob, except: HelloJob do
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_no_performed_jobs_without_block_with_only_and_except_options
    error = assert_raise ArgumentError do
      HelloJob.perform_later('jeremy')
      LoggingJob.perform_later('bogdan')

      perform_enqueued_jobs

      assert_no_performed_jobs only: HelloJob, except: HelloJob
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
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_with_except_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs except: LoggingJob do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_with_only_and_except_option_failure
    error = assert_raise ArgumentError do
      assert_no_performed_jobs only: HelloJob, except: HelloJob do
        HelloJob.perform_later('jeremy')
        LoggingJob.perform_later
      end
    end

    assert_match(/`:only` and `:except`/, error.message)
  end

  def test_assert_no_performed_jobs_with_queue_option
    assert_no_performed_jobs queue: :some_queue do
      HelloJob.set(queue: :other_queue).perform_later('jeremy')
    end
  end

  def test_assert_no_performed_jobs_with_queue_option_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs queue: :some_queue do
        HelloJob.set(queue: :some_queue).perform_later('jeremy')
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_without_block_with_queue_option
    HelloJob.set(queue: :other_queue).perform_later('jeremy')

    perform_enqueued_jobs

    assert_no_performed_jobs queue: :some_queue
  end

  def test_assert_no_performed_jobs_without_block_with_queue_option_failure
    HelloJob.set(queue: :some_queue).perform_later('jeremy')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs queue: :some_queue
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_with_only_and_queue_options
    assert_no_performed_jobs only: HelloJob, queue: :some_queue do
      HelloJob.set(queue: :other_queue).perform_later('bogdan')
      LoggingJob.set(queue: :some_queue).perform_later('jeremy')
    end
  end

  def test_assert_no_performed_jobs_with_only_and_queue_options_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs only: HelloJob, queue: :some_queue do
        HelloJob.set(queue: :some_queue).perform_later('bogdan')
        LoggingJob.set(queue: :some_queue).perform_later('jeremy')
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_without_block_with_only_and_queue_options
    HelloJob.set(queue: :other_queue).perform_later('bogdan')
    LoggingJob.set(queue: :some_queue).perform_later('jeremy')

    perform_enqueued_jobs

    assert_no_performed_jobs only: HelloJob, queue: :some_queue
  end

  def test_assert_no_performed_jobs_without_block_with_only_and_queue_options_failure
    HelloJob.set(queue: :some_queue).perform_later('bogdan')
    LoggingJob.set(queue: :some_queue).perform_later('jeremy')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs only: HelloJob, queue: :some_queue
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_with_except_and_queue_options
    assert_no_performed_jobs except: HelloJob, queue: :some_queue do
      HelloJob.set(queue: :other_queue).perform_later('bogdan')
      HelloJob.set(queue: :some_queue).perform_later('bogdan')
      LoggingJob.set(queue: :other_queue).perform_later('jeremy')
    end
  end

  def test_assert_no_performed_jobs_with_except_and_queue_options_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs except: HelloJob, queue: :some_queue do
        HelloJob.set(queue: :other_queue).perform_later('bogdan')
        HelloJob.set(queue: :some_queue).perform_later('bogdan')
        LoggingJob.set(queue: :some_queue).perform_later('jeremy')
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_no_performed_jobs_without_block_with_except_and_queue_options
    HelloJob.set(queue: :other_queue).perform_later('bogdan')
    HelloJob.set(queue: :some_queue).perform_later('bogdan')
    LoggingJob.set(queue: :other_queue).perform_later('jeremy')

    perform_enqueued_jobs

    assert_no_performed_jobs except: HelloJob, queue: :some_queue
  end

  def test_assert_no_performed_jobs_without_block_with_except_and_queue_options_failure
    HelloJob.set(queue: :other_queue).perform_later('bogdan')
    HelloJob.set(queue: :some_queue).perform_later('bogdan')
    LoggingJob.set(queue: :some_queue).perform_later('jeremy')

    perform_enqueued_jobs

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs except: HelloJob, queue: :some_queue
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_performed_with
    assert_performed_with(job: NestedJob, queue: 'default') do
      NestedJob.perform_later
    end
  end

  def test_assert_performed_with_without_block
    NestedJob.perform_later

    perform_enqueued_jobs

    assert_performed_with(job: NestedJob, queue: 'default')
  end

  def test_assert_performed_with_returns
    job = assert_performed_with(job: LoggingJob, queue: 'default') do
      LoggingJob.perform_later(keyword: :sym)
    end

    assert_instance_of LoggingJob, job
    assert_nil job.scheduled_at
    assert_equal [{ keyword: :sym }], job.arguments
    assert_equal 'default', job.queue_name
  end

  def test_assert_performed_with_without_block_returns
    LoggingJob.perform_later(keyword: :sym)

    perform_enqueued_jobs

    job = assert_performed_with(job: LoggingJob, queue: 'default')

    assert_instance_of LoggingJob, job
    assert_nil job.scheduled_at
    assert_equal [{ keyword: :sym }], job.arguments
    assert_equal 'default', job.queue_name
  end

  def test_assert_performed_with_failure
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: LoggingJob) do
        HelloJob.perform_later
      end
    end

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, queue: 'low') do
        HelloJob.set(queue: 'important').perform_later
      end
    end
  end

  def test_assert_performed_with_without_block_failure
    HelloJob.perform_later

    perform_enqueued_jobs

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: LoggingJob)
    end

    HelloJob.set(queue: 'important').perform_later

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, queue: 'low')
    end
  end

  def test_assert_performed_with_with_at_option
    assert_performed_with(job: HelloJob, at: Date.tomorrow.noon) do
      HelloJob.set(wait_until: Date.tomorrow.noon).perform_later
    end

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, at: Date.today.noon) do
        HelloJob.set(wait_until: Date.tomorrow.noon).perform_later
      end
    end
  end

  def test_assert_performed_with_with_relative_at_option
    assert_performed_with(job: HelloJob, at: 5.minutes.from_now) do
      HelloJob.set(wait: 5.minutes).perform_later
    end

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, at: 2.minutes.from_now) do
        HelloJob.set(wait: 1.minute).perform_later
      end
    end
  end

  def test_assert_performed_with_without_block_with_at_option
    HelloJob.set(wait_until: Date.tomorrow.noon).perform_later

    perform_enqueued_jobs

    assert_performed_with(job: HelloJob, at: Date.tomorrow.noon)

    HelloJob.set(wait_until: Date.tomorrow.noon).perform_later

    perform_enqueued_jobs

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, at: Date.today.noon)
    end
  end

  def test_assert_performed_with_with_hash_arg
    assert_performed_with(job: MultipleKwargsJob, args: [{ argument1: 1, argument2: { a: 1, b: 2 } }]) do
      MultipleKwargsJob.perform_later(argument2: { b: 2, a: 1 }, argument1: 1)
    end
  end

  def test_assert_performed_with_supports_matcher_procs
    facets = {
      job: HelloJob,
      args: ['Rails'],
      at: Date.tomorrow.noon,
      queue: 'important',
    }

    facets[:job].set(queue: facets[:queue], wait_until: facets[:at]).perform_later(*facets[:args])
    perform_enqueued_jobs

    facets.each do |facet, value|
      matcher = ->(job_value) { job_value == value }
      refuser = ->(job_value) { false }

      assert_performed_with(**{ facet => matcher })

      assert_raises ActiveSupport::TestCase::Assertion do
        assert_performed_with(**{ facet => refuser })
      end
    end
  end

  def test_assert_performed_with_time
    now = Time.now
    args = [{ argument1: { now: now }, argument2: now }]

    assert_performed_with(job: MultipleKwargsJob, args: args) do
      MultipleKwargsJob.perform_later(argument1: { now: now }, argument2: now)
    end
  end

  def test_assert_performed_with_date_time
    now = DateTime.now
    args = [{ argument1: { now: now }, argument2: now }]

    assert_performed_with(job: MultipleKwargsJob, args: args) do
      MultipleKwargsJob.perform_later(argument1: { now: now }, argument2: now)
    end
  end

  def test_assert_performed_with_time_with_zone
    now = Time.now.in_time_zone('Tokyo')
    args = [{ argument1: { now: now }, argument2: now }]

    assert_performed_with(job: MultipleKwargsJob, args: args) do
      MultipleKwargsJob.perform_later(argument1: { now: now }, argument2: now)
    end
  end

  def test_assert_performed_with_with_global_id_args
    ricardo = Person.new(9)
    assert_performed_with(job: HelloJob, args: [ricardo]) do
      HelloJob.perform_later(ricardo)
    end
  end

  def test_assert_performed_with_without_block_with_global_id_args
    ricardo = Person.new(9)
    HelloJob.perform_later(ricardo)
    perform_enqueued_jobs
    assert_performed_with(job: HelloJob, args: [ricardo])
  end

  def test_assert_performed_with_failure_with_global_id_args
    ricardo = Person.new(9)
    wilma = Person.new(11)
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, args: [wilma]) do
        HelloJob.perform_later(ricardo)
      end
    end
    assert_match(/No performed job found with {:job=>HelloJob, :args=>\[#{wilma.inspect}\]}/, error.message)
    assert_match(/Potential matches: {.*?:job=>HelloJob, :args=>\[#<Person.* @id=\"9\"\>\], :queue=>\"default\"}/, error.message)
  end

  def test_assert_performed_with_without_block_failure_with_global_id_args
    ricardo = Person.new(9)
    wilma = Person.new(11)
    HelloJob.perform_later(ricardo)
    perform_enqueued_jobs
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: HelloJob, args: [wilma])
    end

    assert_match(/No performed job found with {:job=>HelloJob, :args=>\[#{wilma.inspect}\]}/, error.message)
    assert_match(/Potential matches: {.*?:job=>HelloJob, :args=>\[#<Person.* @id=\"9\"\>\], :queue=>\"default\"}/, error.message)
  end

  def test_assert_performed_with_does_not_change_jobs_count
    assert_performed_with(job: HelloJob) do
      HelloJob.perform_later
    end

    assert_performed_with(job: HelloJob) do
      HelloJob.perform_later
    end

    assert_equal 0, queue_adapter.enqueued_jobs.count
    assert_equal 2, queue_adapter.performed_jobs.count
  end

  def test_assert_performed_with_without_block_does_not_change_jobs_count
    HelloJob.perform_later
    perform_enqueued_jobs
    assert_performed_with(job: HelloJob)

    HelloJob.perform_later
    perform_enqueued_jobs
    assert_performed_with(job: HelloJob)

    assert_equal 0, queue_adapter.enqueued_jobs.count
    assert_equal 2, queue_adapter.performed_jobs.count
  end

  test 'TestAdapter respect max attempts' do
    perform_enqueued_jobs(only: RaisingJob) do
      assert_raises(RaisingJob::MyError) do
        RaisingJob.perform_later
      end
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
