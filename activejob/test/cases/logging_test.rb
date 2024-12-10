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
require "jobs/disable_log_job"
require "jobs/abort_before_enqueue_job"
require "jobs/enqueue_error_job"
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
    ActiveJob::LogSubscriber.attach_to :active_job
  end

  def teardown
    super
    ActiveJob::LogSubscriber.log_subscribers.pop
    set_logger @old_logger
  end

  def set_logger(logger)
    ActiveJob::Base.logger = logger
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
    assert_notifications_count(/enqueue.*\.active_job/, 1) do
      assert_notifications_count("enqueue.active_job", 1) do
        HelloJob.perform_later "Cristian"
      end
    end

    assert_match(/Enqueued HelloJob \(Job ID: .*?\) to .*?:.*Cristian/, @logger.messages)
  end

  def test_enqueue_job_log_error_when_callback_chain_is_halted
    assert_notifications_count(/enqueue.*\.active_job/, 1) do
      assert_notification("enqueue.active_job") do
        AbortBeforeEnqueueJob.perform_later
      end
    end

    assert_match(/Failed enqueuing AbortBeforeEnqueueJob.* a before_enqueue callback halted/, @logger.messages)
  end

  def test_enqueue_job_log_error_when_error_is_raised_during_callback_chain
    assert_notifications_count(/enqueue.*\.active_job/, 1) do
      assert_notification("enqueue.active_job") do
        assert_raises(AbortBeforeEnqueueJob::MyError) do
          AbortBeforeEnqueueJob.perform_later(:raise)
        end
      end
    end

    assert_match(/Failed enqueuing AbortBeforeEnqueueJob/, @logger.messages)
  end

  def test_perform_job_logging
    perform_enqueued_jobs do
      LoggingJob.perform_later "Dummy"
      assert_match(/Performing LoggingJob \(Job ID: .*?\) from .*? with arguments:.*Dummy/, @logger.messages)

      assert_match(/enqueued at /, @logger.messages)
      assert_match(/Dummy, here is it: Dummy/, @logger.messages)
      assert_match(/Performed LoggingJob \(Job ID: .*?\) from .*? in .*ms/, @logger.messages)
    end
  end

  def test_perform_job_logging_when_job_is_not_enqueued
    perform_enqueued_jobs do
      LoggingJob.perform_now "Dummy"

      assert_match(/Performing LoggingJob \(Job ID: .*?\) from .*? with arguments:.*Dummy/, @logger.messages)
      assert_no_match(/enqueued at /, @logger.messages)
    end
  end

  def test_perform_job_log_error_when_callback_chain_is_halted
    AbortBeforeEnqueueJob.perform_now
    assert_match(/Error performing AbortBeforeEnqueueJob.* a before_perform callback halted/, @logger.messages)
  end

  def test_perform_job_doesnt_log_error_when_job_returns_falsy_value
    job = Class.new(ActiveJob::Base) do
      def perform
        nil
      end
    end

    job.perform_now
    assert_no_match(/Error performing AbortBeforeEnqueueJob.* a before_perform callback halted/, @logger.messages)
  end

  def test_perform_job_doesnt_log_error_when_job_is_performed_multiple_times_and_fail_the_first_time
    job = Class.new(ActiveJob::Base) do
      before_perform do
        throw(:abort) if arguments[0].pop == :abort
      end

      def perform(_)
      end
    end.new([:dont_abort, :abort])

    job.perform_now
    job.perform_now

    assert_equal(1, @logger.messages.scan(/a before_perform callback halted the job execution/).size)
  end

  def test_perform_disabled_job_logging
    perform_enqueued_jobs do
      DisableLogJob.perform_later "Dummy"
      assert_no_match(/Enqueued DisableLogJob \(Job ID: .*?\) from .*? with arguments:.*Dummy/, @logger.messages)
      assert_no_match(/Performing DisableLogJob \(Job ID: .*?\) from .*? with arguments:.*Dummy/, @logger.messages)

      assert_match(/enqueued at /, @logger.messages)
      assert_match(/Dummy, here is it: Dummy/, @logger.messages)
      assert_match(/Performed DisableLogJob \(Job ID: .*?\) from .*? in .*ms/, @logger.messages)
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

  unless adapter_is?(:inline, :sneakers)
    def test_enqueue_at_job_logging
      assert_notifications_count(/enqueue.*\.active_job/, 1) do
        assert_notification("enqueue_at.active_job") do
          HelloJob.set(wait_until: 24.hours.from_now).perform_later "Cristian"
        end
      end

      assert_match(/Enqueued HelloJob \(Job ID: .*\) to .*? at.*Cristian/, @logger.messages)
    end
  end

  def test_enqueue_at_job_log_error_when_callback_chain_is_halted
    assert_notifications_count(/enqueue.*\.active_job/, 1) do
      assert_notification("enqueue_at.active_job") do
        AbortBeforeEnqueueJob.set(wait: 1.second).perform_later
      end
    end

    assert_match(/Failed enqueuing AbortBeforeEnqueueJob.* a before_enqueue callback halted/, @logger.messages)
  end

  def test_enqueue_at_job_log_error_when_error_is_raised_during_callback_chain
    assert_notifications_count(/enqueue.*\.active_job/, 1) do
      assert_notification("enqueue_at.active_job") do
        assert_raises(AbortBeforeEnqueueJob::MyError) do
          AbortBeforeEnqueueJob.set(wait: 1.second).perform_later(:raise)
        end
      end
    end

    assert_match(/Failed enqueuing AbortBeforeEnqueueJob/, @logger.messages)
  end

  unless adapter_is?(:inline, :sneakers)
    def test_enqueue_in_job_logging
      assert_notifications_count(/enqueue.*\.active_job/, 1) do
        assert_notification("enqueue_at.active_job") do
          HelloJob.set(wait: 2.seconds).perform_later "Cristian"
        end
      end

      assert_match(/Enqueued HelloJob \(Job ID: .*\) to .*? at.*Cristian/, @logger.messages)
    end
  end

  def test_enqueue_log_when_enqueue_error_is_set
    EnqueueErrorJob.disable_test_adapter

    EnqueueErrorJob.perform_later
    assert_match(/Failed enqueuing EnqueueErrorJob to EnqueueError\(default\): ActiveJob::EnqueueError \(There was an error enqueuing the job\)/, @logger.messages)
  end

  def test_enqueue_at_log_when_enqueue_error_is_set
    EnqueueErrorJob.disable_test_adapter

    EnqueueErrorJob.set(wait: 1.hour).perform_later
    assert_match(/Failed enqueuing EnqueueErrorJob to EnqueueError\(default\): ActiveJob::EnqueueError \(There was an error enqueuing the job\)/, @logger.messages)
  end

  def test_for_tagged_logger_support_is_consistent
    set_logger ::Logger.new(nil)
    assert_nothing_raised do
      OverriddenLoggingJob.perform_later "Dummy"
    end
  end

  def test_job_error_logging
    perform_enqueued_jobs do
      RescueJob.perform_later "other"
    rescue RescueJob::OtherError
      assert_match(/Performing RescueJob \(Job ID: .*?\) from .*? with arguments:.*other/, @logger.messages)
      assert_match(/Error performing RescueJob \(Job ID: .*?\) from .*? in .*ms: RescueJob::OtherError \(Bad hair\):\n.*\brescue_job\.rb:\d+:in .*perform'/, @logger.messages)
    end
  end

  def test_job_no_error_logging_on_rescuable_job
    perform_enqueued_jobs { RescueJob.perform_later "david" }
    assert_match(/Performing RescueJob \(Job ID: .*?\) from .*? with arguments:.*david/, @logger.messages)
    assert_no_match(/Error performing RescueJob \(Job ID: .*?\) from .*? in .*ms: ArgumentError \(Hair too good\):\n.*\brescue_job\.rb:\d+:in .*perform'/, @logger.messages)
  end

  unless adapter_is?(:inline, :sneakers)
    def test_enqueue_retry_logging
      perform_enqueued_jobs do
        RetryJob.perform_later "DefaultsError", 2
        assert_match(/Retrying RetryJob \(Job ID: .*?\) after \d+ attempts in 3 seconds, due to a DefaultsError.*\./, @logger.messages)
      end
    end
  end

  def test_enqueue_retry_logging_on_retry_job
    perform_enqueued_jobs { RescueJob.perform_later "david" }
    assert_match(/Retrying RescueJob \(Job ID: .*?\) after \d+ attempts in 0 seconds\./, @logger.messages)
  end

  unless adapter_is?(:inline, :sneakers)
    def test_retry_stopped_logging
      perform_enqueued_jobs do
        RetryJob.perform_later "CustomCatchError", 6
      end
      assert_match(/Stopped retrying RetryJob \(Job ID: .*?\) due to a CustomCatchError.*, which reoccurred on \d+ attempts\./, @logger.messages)
    end

    def test_retry_stopped_logging_without_block
      perform_enqueued_jobs do
        RetryJob.perform_later "DefaultsError", 6
      rescue DefaultsError
        assert_match(/Stopped retrying RetryJob \(Job ID: .*?\) due to a DefaultsError.*, which reoccurred on \d+ attempts\./, @logger.messages)
      end
    end
  end

  def test_discard_logging
    perform_enqueued_jobs do
      RetryJob.perform_later "DiscardableError", 2
      assert_match(/Discarded RetryJob \(Job ID: .*?\) due to a DiscardableError.*\./, @logger.messages)
    end
  end

  def test_enqueue_all_job_logging_some_jobs_failed_enqueuing
    EnqueueErrorJob.disable_test_adapter

    EnqueueErrorJob::EnqueueErrorAdapter.should_raise_sequence = [false, true]

    ActiveJob.perform_all_later(EnqueueErrorJob.new, EnqueueErrorJob.new)
    assert_match(/Enqueued 1 job to .+ \(1 EnqueueErrorJob\)\. Failed enqueuing 1 job/, @logger.messages)
  ensure
    EnqueueErrorJob::EnqueueErrorAdapter.should_raise_sequence = []
  end

  def test_enqueue_all_job_logging_all_jobs_failed_enqueuing
    EnqueueErrorJob.disable_test_adapter

    EnqueueErrorJob::EnqueueErrorAdapter.should_raise_sequence = [true, true]

    ActiveJob.perform_all_later(EnqueueErrorJob.new, EnqueueErrorJob.new)
    assert_match(/Failed enqueuing 2 jobs to .+/, @logger.messages)
  ensure
    EnqueueErrorJob::EnqueueErrorAdapter.should_raise_sequence = []
  end

  def test_verbose_enqueue_logs
    ActiveJob.verbose_enqueue_logs = true

    LoggingJob.perform_later "Dummy"
    assert_match("↳", @logger.messages)
  ensure
    ActiveJob.verbose_enqueue_logs = false
  end

  def test_verbose_enqueue_logs_disabled_by_default
    LoggingJob.perform_later "Dummy"
    assert_no_match("↳", @logger.messages)
  end

  def test_enqueue_all_job_logging
    ActiveJob.perform_all_later(LoggingJob.new("Dummy"), HelloJob.new("Jamie"), HelloJob.new("John"))
    assert_match(/Enqueued 3 jobs to .+ \(2 HelloJob, 1 LoggingJob\)/, @logger.messages)
  end

  def test_enqueue_all_graceful_failure_when_enqueued_count_is_nil
    original_adapter = ActiveJob::Base.queue_adapter

    stubbed_inline_adapter = ActiveJob::QueueAdapters::InlineAdapter.new
    def stubbed_inline_adapter.respond_to?(method_name, include_private = false)
      method_name == :enqueue_all || super
    end
    def stubbed_inline_adapter.enqueue_all(*)
      nil
    end

    ActiveJob::Base.queue_adapter = stubbed_inline_adapter

    ActiveJob.perform_all_later(LoggingJob.new("Dummy"), HelloJob.new("Jamie"), HelloJob.new("John"))
    assert_match(/Failed enqueuing 3 jobs to .+/, @logger.messages)
  ensure
    ActiveJob::Base.queue_adapter = original_adapter
  end

  def test_enqueue_log_level
    @logger.level = WARN
    HelloJob.perform_later "Dummy"
    assert_no_match(/HelloJob/, @logger.messages)
    assert_empty @logger.messages

    @logger.level = INFO
    LoggingJob.perform_later "Dummy"
    assert_match(/Enqueued LoggingJob \(Job ID: .*?\) to .*? with arguments:.*Dummy/, @logger.messages)
  end

  unless adapter_is?(:inline, :sneakers)
    def test_enqueue_at_log_level
      @logger.level = WARN
      HelloJob.set(wait_until: 24.hours.from_now).perform_later "Cristian"
      assert_no_match(/HelloJob/, @logger.messages)
      assert_empty @logger.messages

      @logger.level = INFO
      LoggingJob.set(wait_until: 24.hours.from_now).perform_later "Dummy"
      assert_match(/Enqueued LoggingJob \(Job ID: .*\) to .*? at.*Dummy/, @logger.messages)
    end
  end

  def test_enqueue_all_log_level
    @logger.level = WARN
    ActiveJob.perform_all_later(LoggingJob.new("Dummy"), HelloJob.new("Jamie"), HelloJob.new("John"))
    assert_no_match(/\(2 HelloJob, 1 LoggingJob\)/, @logger.messages)
    assert_empty @logger.messages

    @logger.level = INFO
    ActiveJob.perform_all_later(LoggingJob.new("Dummy"), HelloJob.new("Jamie"), HelloJob.new("John"))
    assert_match(/Enqueued 3 jobs to .+ \(2 HelloJob, 1 LoggingJob\)/, @logger.messages)
  end

  def test_perform_start_log_level
    @logger.level = WARN
    perform_enqueued_jobs { LoggingJob.perform_later "Dummy" }
    assert_no_match(/LoggingJob/, @logger.messages)
    assert_empty @logger.messages

    @logger.level = INFO
    perform_enqueued_jobs { LoggingJob.perform_later "Dummy" }
    assert_match(/Performing LoggingJob \(Job ID: .*?\) from .*? with arguments:.*Dummy/, @logger.messages)
  end

  def test_perform_log_level
    @logger.level = WARN
    perform_enqueued_jobs { LoggingJob.perform_later "Dummy" }
    assert_no_match(/Dummy, here is it: Dummy/, @logger.messages)
    assert_empty @logger.messages

    @logger.level = INFO
    perform_enqueued_jobs { LoggingJob.perform_later "Dummy" }
    assert_match(/Dummy, here is it: Dummy/, @logger.messages)
  end

  unless adapter_is?(:inline, :sneakers)
    def test_enqueue_retry_log_level
      @logger.level = WARN
      perform_enqueued_jobs { RetryJob.perform_later "DefaultsError", 2 }
      assert_no_match(/RetryJob/, @logger.messages)
      assert_empty @logger.messages

      @logger.level = INFO
      perform_enqueued_jobs { RetryJob.perform_later "DefaultsError", 2 }
      assert_match(/Retrying RetryJob \(Job ID: .*?\) after \d+ attempts in 3 seconds, due to a DefaultsError.*\./, @logger.messages)
    end
  end

  def test_enqueue_retry_log_level_on_retry_job
    @logger.level = WARN
    perform_enqueued_jobs { RescueJob.perform_later "david" }
    assert_no_match(/RescueJob/, @logger.messages)
    assert_empty @logger.messages

    @logger.level = INFO
    perform_enqueued_jobs { RescueJob.perform_later "david" }
    assert_match(/Retrying RescueJob \(Job ID: .*?\) after \d+ attempts in 0 seconds\./, @logger.messages)
  end

  unless adapter_is?(:inline, :sneakers)
    def test_retry_stopped_log_level
      @logger.level = FATAL
      perform_enqueued_jobs { RetryJob.perform_later "CustomCatchError", 6 }
      assert_no_match(/RetryJob/, @logger.messages)
      assert_empty @logger.messages

      @logger.level = ERROR
      perform_enqueued_jobs { RetryJob.perform_later "CustomCatchError", 6 }
      assert_match(/Stopped retrying RetryJob \(Job ID: .*?\) due to a CustomCatchError.*, which reoccurred on \d+ attempts\./, @logger.messages)
    end
  end

  def test_discard_log_level
    @logger.level = FATAL
    perform_enqueued_jobs { RetryJob.perform_later "DiscardableError", 2 }
    assert_no_match(/RetryJob/, @logger.messages)
    assert_empty @logger.messages

    @logger.level = ERROR
    perform_enqueued_jobs { RetryJob.perform_later "DiscardableError", 2 }
    assert_match(/Discarded RetryJob \(Job ID: .*?\) due to a DiscardableError.*\./, @logger.messages)
  end
end
