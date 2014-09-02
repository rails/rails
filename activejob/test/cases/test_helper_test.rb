require 'helper'
require 'active_support/core_ext/time'
require 'active_support/core_ext/date'
require 'jobs/hello_job'
require 'jobs/logging_job'
require 'jobs/nested_job'

class EnqueuedJobsTest < ActiveJob::TestCase
  setup { queue_adapter.perform_enqueued_at_jobs = true }

  def test_assert_enqueued_jobs
    assert_nothing_raised do
      assert_enqueued_jobs 1 do
        HelloJob.enqueue('david')
      end
    end
  end

  def test_repeated_enqueued_jobs_calls
    assert_nothing_raised do
      assert_enqueued_jobs 1 do
        HelloJob.enqueue('abdelkader')
      end
    end

    assert_nothing_raised do
      assert_enqueued_jobs 2 do
        HelloJob.enqueue('sean')
        HelloJob.enqueue('yves')
      end
    end
  end

  def test_assert_enqueued_jobs_with_no_block
    assert_nothing_raised do
      HelloJob.enqueue('rafael')
      assert_enqueued_jobs 1
    end

    assert_nothing_raised do
      HelloJob.enqueue('aaron')
      HelloJob.enqueue('matthew')
      assert_enqueued_jobs 3
    end
  end

  def test_assert_no_enqueued_jobs
    assert_nothing_raised do
      assert_no_enqueued_jobs do
        # Scheduled jobs are being performed in this context
        HelloJob.enqueue_at(Date.tomorrow.noon, 'godfrey')
      end
    end
  end

  def test_assert_enqueued_jobs_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 2 do
        HelloJob.enqueue('xavier')
      end
    end

    assert_match(/2 .* but 1/, error.message)
  end

  def test_assert_enqueued_jobs_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_jobs 1 do
        HelloJob.enqueue('cristian')
        HelloJob.enqueue('guillermo')
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_no_enqueued_jobs_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_enqueued_jobs do
        HelloJob.enqueue('jeremy')
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_enqueued_job
    assert_enqueued_with(job: LoggingJob, queue: 'default') do
      NestedJob.enqueue_at(Date.tomorrow.noon)
    end
  end

  def test_assert_enqueued_job_failure
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: LoggingJob, queue: 'default') do
        NestedJob.enqueue
      end
    end

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: NestedJob, queue: 'low') do
        NestedJob.enqueue
      end
    end
  end

  def test_assert_enqueued_job_args
    assert_raise ArgumentError do
      assert_enqueued_with(class: LoggingJob) do
        NestedJob.enqueue_at(Date.tomorrow.noon)
      end
    end
  end
end

class PerformedJobsTest < ActiveJob::TestCase
  setup { queue_adapter.perform_enqueued_jobs = true }

  def test_assert_performed_jobs
    assert_nothing_raised do
      assert_performed_jobs 1 do
        HelloJob.enqueue('david')
      end
    end
  end

  def test_repeated_performed_jobs_calls
    assert_nothing_raised do
      assert_performed_jobs 1 do
        HelloJob.enqueue('abdelkader')
      end
    end

    assert_nothing_raised do
      assert_performed_jobs 2 do
        HelloJob.enqueue('sean')
        HelloJob.enqueue('yves')
      end
    end
  end

  def test_assert_performed_jobs_with_no_block
    assert_nothing_raised do
      HelloJob.enqueue('rafael')
      assert_performed_jobs 1
    end

    assert_nothing_raised do
      HelloJob.enqueue('aaron')
      HelloJob.enqueue('matthew')
      assert_performed_jobs 3
    end
  end

  def test_assert_no_performed_jobs
    assert_nothing_raised do
      assert_no_performed_jobs do
        # Scheduled jobs are being enqueued in this context
        HelloJob.enqueue_at(Date.tomorrow.noon, 'godfrey')
      end
    end
  end

  def test_assert_performed_jobs_too_few_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 2 do
        HelloJob.enqueue('xavier')
      end
    end

    assert_match(/2 .* but 1/, error.message)
  end

  def test_assert_performed_jobs_too_many_sent
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_jobs 1 do
        HelloJob.enqueue('cristian')
        HelloJob.enqueue('guillermo')
      end
    end

    assert_match(/1 .* but 2/, error.message)
  end

  def test_assert_no_performed_jobs_failure
    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_no_performed_jobs do
        HelloJob.enqueue('jeremy')
      end
    end

    assert_match(/0 .* but 1/, error.message)
  end

  def test_assert_performed_job
    assert_performed_with(job: NestedJob, queue: 'default') do
      NestedJob.enqueue
    end
  end

  def test_assert_performed_job_failure
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: LoggingJob, queue: 'default') do
        NestedJob.enqueue_at(Date.tomorrow.noon)
      end
    end

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: NestedJob, queue: 'low') do
        NestedJob.enqueue_at(Date.tomorrow.noon)
      end
    end
  end
end
