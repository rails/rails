require 'helper'
require "active_support/log_subscriber/test_helper"
require 'jobs/logging_job'
require 'jobs/nested_job'

class AdapterTest < ActiveSupport::TestCase
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
    $BUFFER = []
    @old_logger = ActiveJob::Base.logger
    @logger = ActiveSupport::TaggedLogging.new(TestLogger.new)
    set_logger @logger
    ActiveJob::Logging::LogSubscriber.attach_to :active_job
  end

  def teardown
    super
    ActiveJob::Logging::LogSubscriber.log_subscribers.pop
    ActiveJob::Base.logger = @old_logger
  end

  def set_logger(logger)
    ActiveJob::Base.logger = logger
  end


  def test_uses_active_job_as_tag
    HelloJob.enqueue "Cristian"
    assert_match(/\[ActiveJob\]/, @logger.messages)
  end

  def test_enqueue_job_logging
    HelloJob.enqueue "Cristian"
    assert_match(/Enqueued HelloJob to .*?:.*Cristian/, @logger.messages)
  end

  def test_perform_job_logging
    LoggingJob.enqueue "Dummy"
    assert_match(/Performing LoggingJob from .*? with arguments:.*Dummy/, @logger.messages)
    assert_match(/Dummy, here is it: Dummy/, @logger.messages)
    assert_match(/Performed LoggingJob from .*? in .*ms/, @logger.messages)
  end

  def test_perform_uses_job_name_job_logging
    LoggingJob.enqueue "Dummy"
    assert_match(/\[LoggingJob\]/, @logger.messages)
  end

  def test_perform_uses_job_id_job_logging
    LoggingJob.enqueue "Dummy"
    assert_match(/\[LOGGING-JOB-ID\]/, @logger.messages)
  end

  def test_perform_nested_jobs_logging
    NestedJob.enqueue
    assert_match(/\[LoggingJob\] \[.*?\]/, @logger.messages)
    assert_match(/\[ActiveJob\] Enqueued NestedJob to/, @logger.messages)
    assert_match(/\[ActiveJob\] \[NestedJob\] \[NESTED-JOB-ID\] Performing NestedJob from/, @logger.messages)
    assert_match(/\[ActiveJob\] \[NestedJob\] \[NESTED-JOB-ID\] Enqueued LoggingJob to .* with arguments: "NestedJob"/, @logger.messages)
    assert_match(/\[ActiveJob\].*\[LoggingJob\] \[LOGGING-JOB-ID\] Performing LoggingJob from .* with arguments: "NestedJob"/, @logger.messages)
    assert_match(/\[ActiveJob\].*\[LoggingJob\] \[LOGGING-JOB-ID\] Dummy, here is it: NestedJob/, @logger.messages)
    assert_match(/\[ActiveJob\].*\[LoggingJob\] \[LOGGING-JOB-ID\] Performed LoggingJob from .* in/, @logger.messages)
    assert_match(/\[ActiveJob\] \[NestedJob\] \[NESTED-JOB-ID\] Performed NestedJob from .* in/, @logger.messages)
  end

  def test_enqueue_at_job_logging
    HelloJob.enqueue_at 1, "Cristian"
    assert_match(/Enqueued HelloJob to .*? at.*Cristian/, @logger.messages)
  rescue NotImplementedError
    skip
  end

  def test_enqueue_in_job_logging
    HelloJob.enqueue_in 2, "Cristian"
    assert_match(/Enqueued HelloJob to .*? at.*Cristian/, @logger.messages)
  rescue NotImplementedError
    skip
  end
end
