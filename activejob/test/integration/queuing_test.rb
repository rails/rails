require 'helper'
require 'jobs/logging_job'
require 'active_support/core_ext/numeric/time'

class QueuingTest < ActiveSupport::TestCase
  test 'should run jobs enqueued on a listening queue' do
    TestJob.perform_later @id
    wait_for_jobs_to_finish_for(5.seconds)
    assert job_executed
  end

  test 'should not run jobs queued on a non-listening queue' do
    skip if adapter_is?(:inline) || adapter_is?(:sucker_punch)
    old_queue = TestJob.queue_name

    begin
      TestJob.queue_as :some_other_queue
      TestJob.perform_later @id
      wait_for_jobs_to_finish_for(2.seconds)
      assert_not job_executed
    ensure
      TestJob.queue_name = old_queue
    end
  end

  test 'should not run job enqueued in the future' do
    begin
      TestJob.set(wait: 10.minutes).perform_later @id
      wait_for_jobs_to_finish_for(5.seconds)
      assert_not job_executed
    rescue NotImplementedError
      skip
    end
  end

  test 'should run job enqueued in the future at the specified time' do
    begin
      TestJob.set(wait: 3.seconds).perform_later @id
      wait_for_jobs_to_finish_for(2.seconds)
      assert_not job_executed
      wait_for_jobs_to_finish_for(10.seconds)
      assert job_executed
    rescue NotImplementedError
      skip
    end
  end
end
