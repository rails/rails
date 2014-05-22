require 'helper'
require 'jobs/hello_job'
require 'active_support/core_ext/numeric/time'


class QueuingTest < ActiveSupport::TestCase
  setup do
    $BUFFER = []
  end

  test 'run queued job' do
    HelloJob.enqueue
    assert_equal "David says hello", $BUFFER.pop
  end

  test 'run queued job with arguments' do
    HelloJob.enqueue "Jamie"
    assert_equal "Jamie says hello", $BUFFER.pop
  end

  test 'run queued job later' do
    begin
      result = HelloJob.enqueue_at 1.second.ago, "Jamie"
      assert result
    rescue NotImplementedError
      skip
    end
  end
  
  test 'job returned by enqueue has the arguments available' do
    job = HelloJob.enqueue "Jamie"
    assert_equal [ "Jamie" ], job.arguments
  end

  
  test 'job returned by enqueue_at has the timestamp available' do
    begin
      job = HelloJob.enqueue_at Time.utc(2014, 1, 1)
      assert_equal Time.utc(2014, 1, 1), job.enqueued_at
    rescue NotImplementedError
      skip
    end
  end
end
