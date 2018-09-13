# frozen_string_literal: true

require "helper"
require "active_support/log_subscriber/test_helper"
require "active_support/core_ext/numeric/time"
require "jobs/hello_job"
require "jobs/logging_job"
require "jobs/overridden_logging_job"
require "jobs/nested_job"
require "jobs/rescue_job"
require "jobs/retry_job"
require "models/person"

class LoggingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::LogSubscriber::TestHelper
  include ActiveSupport::Logger::Severity

  class TestLogger < ActiveSupport::Logger
    def initialize
      @file = StringIO.new
      super(@file)
    end

    def messages
      @file.rewind
      @file.read
    end
  end

  def setup
    super
    JobBuffer.clear
    @old_logger = ActiveJob::Base.logger
    @logger = ActiveSupport::TaggedLogging.new(TestLogger.new)
    set_logger @logger
    ActiveJob::Logging::LogSubscriber.attach_to :active_job
  end

  def teardown
    super
    ActiveJob::Logging::LogSubscriber.log_subscribers.pop
    set_logger @old_logger
  end

  def set_logger(logger)
    ActiveJob::Base.logger = logger
  end

  def subscribed
    [].tap do |events|
      ActiveSupport::Notifications.subscribed(-> (*args) { events << args }, /enqueue.*\.active_job/) do
        yield
      end
    end
  end

  def test_uses_active_job_as_tag
    HelloJob.perform_later "Cristian"
    assert_match(/\[ActiveJob\]/, @logger.messages)
  end

  def test_uses_job_name_as_tag
    perform_enqueued_jobs do
      LoggingJob.perform_later "Dummy"
      assert_match(/\[LoggingJob\]/, @logger.messages)
    end
  end

  def test_uses_job_id_as_tag
    perform_enqueued_jobs do
      LoggingJob.perform_later "Dummy"
      assert_match(/\[LOGGING-JOB-ID\]/, @logger.messages)
    end
  end

  def test_logs_correct_queue_name
    original_queue_name = LoggingJob.queue_name
    LoggingJob.queue_as :php_jobs
    LoggingJob.perform_later("Dummy")
    assert_match(/to .*?\(php_jobs\).*/, @logger.messages)
  ensure
    LoggingJob.queue_name = original_queue_name
  end

  def test_globalid_parameter_logging
    perform_enqueued_jobs do
      person = Person.new(123)
      LoggingJob.perform_later person
      assert_match(%r{Enqueued.*gid://aj/Person/123}, @logger.messages)
      assert_match(%r{Dummy, here is it: #<Person:.*>}, @logger.messages)
      assert_match(%r{Performing.*gid://aj/Person/123}, @logger.messages)
    end
  end

  def test_globalid_nested_parameter_logging
    perform_enqueued_jobs do
      person = Person.new(123)
      LoggingJob.perform_later(person: person)
      assert_match(%r{Enqueued.*gid://aj/Person/123}, @logger.messages)
      assert_match(%r{Dummy, here is it: .*#<Person:.*>}, @logger.messages)
      assert_match(%r{Performing.*gid://aj/Person/123}, @logger.messages)
    end
  end

  def test_enqueue_job_logging
    events = subscribed { HelloJob.perform_later "Cristian" }
    assert_match(/Enqueued HelloJob \(Job ID: .*?\) to .*?:.*Cristian/, @logger.messages)
    assert_equal(events.count, 1)
    key, * = events.first
    assert_equal(key, "enqueue.active_job")
  end

  def test_perform_job_logging
    perform_enqueued_jobs do
      LoggingJob.perform_later "Dummy"
      assert_match(/Performing LoggingJob \(Job ID: .*?\) from .*? with arguments:.*Dummy/, @logger.messages)
      assert_match(/Dummy, here is it: Dummy/, @logger.messages)
      assert_match(/Performed LoggingJob \(Job ID: .*?\) from .*? in .*ms/, @logger.messages)
    end
  end

  def test_perform_nested_jobs_logging
    perform_enqueued_jobs do
      NestedJob.perform_later
      assert_match(/\[LoggingJob\] \[.*?\]/, @logger.messages)
      assert_match(/\[ActiveJob\] Enqueued NestedJob \(Job ID: .*\) to/, @logger.messages)
      assert_match(/\[ActiveJob\] \[NestedJob\] \[NESTED-JOB-ID\] Performing NestedJob \(Job ID: .*?\) from/, @logger.messages)
      assert_match(/\[ActiveJob\] \[NestedJob\] \[NESTED-JOB-ID\] Enqueued LoggingJob \(Job ID: .*?\) to .* with arguments: "NestedJob"/, @logger.messages)
      assert_match(/\[ActiveJob\].*\[LoggingJob\] \[LOGGING-JOB-ID\] Performing LoggingJob \(Job ID: .*?\) from .* with arguments: "NestedJob"/, @logger.messages)
      assert_match(/\[ActiveJob\].*\[LoggingJob\] \[LOGGING-JOB-ID\] Dummy, here is it: NestedJob/, @logger.messages)
      assert_match(/\[ActiveJob\].*\[LoggingJob\] \[LOGGING-JOB-ID\] Performed LoggingJob \(Job ID: .*?\) from .* in/, @logger.messages)
      assert_match(/\[ActiveJob\] \[NestedJob\] \[NESTED-JOB-ID\] Performed NestedJob \(Job ID: .*?\) from .* in/, @logger.messages)
    end
  end

  def test_enqueue_at_job_logging
    events = subscribed { HelloJob.set(wait_until: 24.hours.from_now).perform_later "Cristian" }
    assert_match(/Enqueued HelloJob \(Job ID: .*\) to .*? at.*Cristian/, @logger.messages)
    assert_equal(events.count, 1)
    key, * = events.first
    assert_equal(key, "enqueue_at.active_job")
  rescue NotImplementedError
    skip
  end

  def test_enqueue_in_job_logging
    events = subscribed { HelloJob.set(wait: 2.seconds).perform_later "Cristian" }
    assert_match(/Enqueued HelloJob \(Job ID: .*\) to .*? at.*Cristian/, @logger.messages)
    assert_equal(events.count, 1)
    key, * = events.first
    assert_equal(key, "enqueue_at.active_job")
  rescue NotImplementedError
    skip
  end

  def test_for_tagged_logger_support_is_consistent
    set_logger ::Logger.new(nil)
    OverriddenLoggingJob.perform_later "Dummy"
  end

  def test_job_error_logging
    perform_enqueued_jobs { RescueJob.perform_later "other" }
  rescue RescueJob::OtherError
    assert_match(/Performing RescueJob \(Job ID: .*?\) from .*? with arguments:.*other/, @logger.messages)
    assert_match(/Error performing RescueJob \(Job ID: .*?\) from .*? in .*ms: RescueJob::OtherError \(Bad hair\):\n.*\brescue_job\.rb:\d+:in `perform'/, @logger.messages)
  end

  def test_enqueue_retry_logging
    perform_enqueued_jobs do
      RetryJob.perform_later "DefaultsError", 2
      assert_match(/Retrying RetryJob in \d+ seconds, due to a DefaultsError\. The original exception was nil\./, @logger.messages)
    end
  end

  def test_retry_stopped_logging
    perform_enqueued_jobs do
      RetryJob.perform_later "CustomCatchError", 6
      assert_match(/Stopped retrying RetryJob due to a CustomCatchError, which reoccurred on \d+ attempts\. The original exception was #<CustomCatchError: CustomCatchError>\./, @logger.messages)
    end
  end

  def test_retry_stopped_logging_without_block
    perform_enqueued_jobs do
      begin
        RetryJob.perform_later "DefaultsError", 6
      rescue DefaultsError
        assert_match(/Stopped retrying RetryJob due to a DefaultsError, which reoccurred on \d+ attempts\. The original exception was #<DefaultsError: DefaultsError>\./, @logger.messages)
      end
    end
  end

  def test_discard_logging
    perform_enqueued_jobs do
      RetryJob.perform_later "DiscardableError", 2
      assert_match(/Discarded RetryJob due to a DiscardableError\. The original exception was nil\./, @logger.messages)
    end
  end
end
