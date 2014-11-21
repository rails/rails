require 'helper'
require 'active_support/core_ext/time'
require 'active_support/core_ext/date'
require 'jobs/hello_job'
require 'jobs/logging_job'
require 'jobs/nested_job'

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

  def test_assert_enqueued_job
    assert_enqueued_with(job: LoggingJob, queue: 'default') do
      LoggingJob.set(wait_until: Date.tomorrow.noon).perform_later
    end
  end

  def test_assert_enqueued_job_failure
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: LoggingJob, queue: 'default') do
        NestedJob.perform_later
      end
    end

    error = assert_raise ActiveSupport::TestCase::Assertion do
      assert_enqueued_with(job: NestedJob, queue: 'low') do
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
end

class PerformedJobsTest < ActiveJob::TestCase
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

  def test_assert_performed_job
    assert_performed_with(job: NestedJob, queue: 'default') do
      NestedJob.perform_later
    end
  end

  def test_assert_performed_job_failure
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: LoggingJob, at: Date.tomorrow.noon, queue: 'default') do
        NestedJob.set(wait_until: Date.tomorrow.noon).perform_later
      end
    end

    assert_raise ActiveSupport::TestCase::Assertion do
      assert_performed_with(job: NestedJob, at: Date.tomorrow.noon, queue: 'low') do
        NestedJob.set(queue: 'low', wait_until: Date.tomorrow.noon).perform_later
      end
    end
  end
end
