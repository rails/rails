require 'helper'
require 'jobs/hello_job'

class QueueNamingTest < ActiveSupport::TestCase
  test 'name derived from base' do
    assert_equal "active_jobs", HelloJob.queue_name
  end
  
  test 'name appended in job' do
    begin
      HelloJob.queue_as :greetings
      assert_equal "active_jobs_greetings", HelloJob.queue_name
    ensure
      HelloJob.queue_name = HelloJob.queue_base_name
    end
  end
end
