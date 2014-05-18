require 'helper'
require 'jobs/hello_job'


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
end
