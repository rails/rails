require 'helper'
require "active_support/log_subscriber/test_helper"

class AdapterTest < ActiveSupport::TestCase
  include ActiveSupport::LogSubscriber::TestHelper
  include ActiveSupport::Logger::Severity

  def setup
    super
    $BUFFER = []
    @old_logger = ActiveJob::Base.logger
    ActiveJob::Base.logger = @logger
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

  def test_enqueue_job_logging
    HelloJob.enqueue "Cristian"
    assert_match(/Enqueued HelloJob to .*?:.*Cristian/, @logger.logged(:info).join)
  end

  def test_perform_job_logging
    HelloJob.enqueue "Cristian"
    assert_match(/Performed HelloJob to .*?:.*Cristian/, @logger.logged(:info).join)
  end

  def test_enqueue_at_job_logging
    HelloJob.enqueue_at 1, "Cristian"
    assert_match(/Enqueued HelloJob to .*? at.*Cristian/, @logger.logged(:info).join)
  rescue NotImplementedError
    skip
  end

  def test_enqueue_in_job_logging
    HelloJob.enqueue_in 2, "Cristian"
    assert_match(/Enqueued HelloJob to .*? at.*Cristian/, @logger.logged(:info).join)
  rescue NotImplementedError
    skip
  end
end
