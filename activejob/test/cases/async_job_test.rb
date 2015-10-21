require 'helper'
require 'jobs/hello_job'
require 'jobs/queue_as_job'

class AsyncJobTest < ActiveSupport::TestCase
  def using_async_adapter?
    ActiveJob::Base.queue_adapter.is_a? ActiveJob::QueueAdapters::AsyncAdapter
  end

  setup do
    ActiveJob::AsyncJob.perform_asynchronously!
  end

  teardown do
    ActiveJob::AsyncJob::QUEUES.clear
    ActiveJob::AsyncJob.perform_immediately!
  end

  test "#create_thread_pool returns a thread_pool" do
    thread_pool = ActiveJob::AsyncJob.create_thread_pool
    assert thread_pool.is_a? Concurrent::ExecutorService
    assert_not thread_pool.is_a? Concurrent::ImmediateExecutor
  end

  test "#create_thread_pool returns an ImmediateExecutor after #perform_immediately! is called" do
    ActiveJob::AsyncJob.perform_immediately!
    thread_pool = ActiveJob::AsyncJob.create_thread_pool
    assert thread_pool.is_a? Concurrent::ImmediateExecutor
  end

  test "enqueuing without specifying a queue uses the default queue" do
    skip unless using_async_adapter?
    HelloJob.perform_later
    assert ActiveJob::AsyncJob::QUEUES.key? 'default'
  end

  test "enqueuing to a queue that does not exist creates the queue" do
    skip unless using_async_adapter?
    QueueAsJob.perform_later
    assert ActiveJob::AsyncJob::QUEUES.key? QueueAsJob::MY_QUEUE.to_s
  end
end
