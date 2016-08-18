require "helper"
require "jobs/logging_job"
require "jobs/hello_job"
require "jobs/provider_jid_job"
require "active_support/core_ext/numeric/time"

class QueuingTest < ActiveSupport::TestCase
  test "should run jobs enqueued on a listening queue" do
    TestJob.perform_later @id
    wait_for_jobs_to_finish_for(5.seconds)
    assert job_executed
  end

  test "should not run jobs queued on a non-listening queue" do
    skip if adapter_is?(:inline, :async, :sucker_punch, :que)
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

  test "should supply a wrapped class name to Sidekiq" do
    skip unless adapter_is?(:sidekiq)
    Sidekiq::Testing.fake! do
      ::HelloJob.perform_later
      hash = ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper.jobs.first
      assert_equal "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper", hash["class"]
      assert_equal "HelloJob", hash["wrapped"]
    end
  end

  test "should access provider_job_id inside Sidekiq job" do
    skip unless adapter_is?(:sidekiq)
    Sidekiq::Testing.inline! do
      job = ::ProviderJidJob.perform_later
      assert_equal "Provider Job ID: #{job.provider_job_id}", JobBuffer.last_value
    end
  end

  test "resque JobWrapper should have instance variable queue" do
    skip unless adapter_is?(:resque)
    job = ::HelloJob.set(wait: 5.seconds).perform_later
    hash = Resque.decode(Resque.find_delayed_selection { true }[0])
    assert_equal hash["queue"], job.queue_name
  end

  test "should not run job enqueued in the future" do
    begin
      TestJob.set(wait: 10.minutes).perform_later @id
      wait_for_jobs_to_finish_for(5.seconds)
      assert_not job_executed
    rescue NotImplementedError
      skip
    end
  end

  test "should run job enqueued in the future at the specified time" do
    begin
      TestJob.set(wait: 5.seconds).perform_later @id
      wait_for_jobs_to_finish_for(2.seconds)
      assert_not job_executed
      wait_for_jobs_to_finish_for(10.seconds)
      assert job_executed
    rescue NotImplementedError
      skip
    end
  end

  test "should supply a provider_job_id when available for immediate jobs" do
    skip unless adapter_is?(:async, :delayed_job, :sidekiq, :qu, :que, :queue_classic)
    test_job = TestJob.perform_later @id
    assert test_job.provider_job_id, "Provider job id should be set by provider"
  end

  test "should supply a provider_job_id when available for delayed jobs" do
    skip unless adapter_is?(:async, :delayed_job, :sidekiq, :que, :queue_classic)
    delayed_test_job = TestJob.set(wait: 1.minute).perform_later @id
    assert delayed_test_job.provider_job_id, "Provider job id should by set for delayed jobs by provider"
  end

  test "current locale is kept while running perform_later" do
    skip if adapter_is?(:inline)

    begin
      I18n.available_locales = [:en, :de]
      I18n.locale = :de

      TestJob.perform_later @id
      wait_for_jobs_to_finish_for(5.seconds)
      assert job_executed
      assert_equal "de", job_executed_in_locale
    ensure
      I18n.available_locales = [:en]
      I18n.locale = :en
    end
  end

  test "should run job with higher priority first" do
    skip unless adapter_is?(:delayed_job, :que)

    wait_until = Time.now + 3.seconds
    TestJob.set(wait_until: wait_until, priority: 20).perform_later "#{@id}.1"
    TestJob.set(wait_until: wait_until, priority: 10).perform_later "#{@id}.2"
    wait_for_jobs_to_finish_for(10.seconds)
    assert job_executed "#{@id}.1"
    assert job_executed "#{@id}.2"
    assert job_executed_at("#{@id}.2") < job_executed_at("#{@id}.1")
  end
end
