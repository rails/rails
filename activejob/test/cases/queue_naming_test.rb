require 'helper'
require 'jobs/hello_job'

class QueueNamingTest < ActiveSupport::TestCase
  test 'name derived from base' do
    assert_equal "active_jobs", HelloJob.queue_name
  end
  
  test 'name appended in job' do
    begin
      HelloJob.queue_as :greetings
      LoggingJob.queue_as :bookkeeping

      assert_equal "active_jobs", NestedJob.queue_name
      assert_equal "active_jobs_greetings", HelloJob.queue_name
      assert_equal "active_jobs_bookkeeping", LoggingJob.queue_name
    ensure
      HelloJob.queue_name = LoggingJob.queue_name = ActiveJob::Base.queue_base_name
    end
  end
end
