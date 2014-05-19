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

  test 'run queued job with parameters' do
    HelloJob.enqueue "Jamie"
    assert_equal "Jamie says hello", $BUFFER.pop
  end

  test 'run queued job later' do
    begin
      result = HelloJob.enqueue_at 1.second.ago, "Jamie"
      assert_not_nil result
    rescue NotImplementedError
    end
  end
end
