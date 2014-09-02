require 'helper'
require 'jobs/hello_job'
require 'jobs/logging_job'
require 'jobs/nested_job'

class QueueNamingTest < ActiveSupport::TestCase
  test 'name derived from base' do
    assert_equal "default", HelloJob.queue_name
  end

  test 'name appended in job' do
    begin
      HelloJob.queue_as :greetings
      LoggingJob.queue_as :bookkeeping

      assert_equal "default", NestedJob.queue_name
      assert_equal "greetings", HelloJob.queue_name
      assert_equal "bookkeeping", LoggingJob.queue_name
    ensure
      HelloJob.queue_name = LoggingJob.queue_name = ActiveJob::Base.default_queue_name
    end
  end

  test 'should prefix the queue name' do
    begin
      original_queue_name_prefix = ActiveJob::Base.queue_name_prefix
      original_queue_name = HelloJob.queue_name

      ActiveJob::Base.queue_name_prefix = 'aj'
      HelloJob.queue_as :low
      assert_equal 'aj_low', HelloJob.queue_name
    ensure
      ActiveJob::Base.queue_name_prefix = original_queue_name_prefix
      HelloJob.queue_name = original_queue_name
    end
  end

end
