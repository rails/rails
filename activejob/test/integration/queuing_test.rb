require 'helper'
require 'jobs/logging_job'
require 'jobs/hello_job'
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

  test 'should supply a wrapped class name to Sidekiq' do
    skip unless adapter_is?(:sidekiq)
    require 'sidekiq/testing'

    Sidekiq::Testing.fake! do
      ::HelloJob.perform_later
      hash = ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper.jobs.first
      assert_equal "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper", hash['class']
      assert_equal "HelloJob", hash['wrapped']
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

  test 'current locale is kept while running perform_later' do
    skip if adapter_is?(:inline)

    begin
      I18n.available_locales = [:en, :de]
      I18n.locale = :de

      TestJob.perform_later @id
      wait_for_jobs_to_finish_for(5.seconds)
      assert job_executed
      assert_equal 'de', job_output
    ensure
      I18n.available_locales = [:en]
      I18n.locale = :en
    end
  end
end
