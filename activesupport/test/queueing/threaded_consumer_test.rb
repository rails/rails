require 'abstract_unit'
require 'active_support/queueing'
require "active_support/log_subscriber/test_helper"

class TestThreadConsumer < ActiveSupport::TestCase
  class Job
    attr_reader :id
    def initialize(id, &block)
      @id = id
      @block = block
    end

    def run
      @block.call if @block
    end
  end

  def setup
    @queue = ActiveSupport::Queue.new
    @logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    @consumer = ActiveSupport::ThreadedQueueConsumer.start(@queue, @logger)
  end

  def teardown
    @queue.push nil
  end

  test "the jobs are executed" do
    ran = false

    job = Job.new(1) do
      ran = true
    end

    @queue.push job
    sleep 0.1
    assert_equal true, ran
  end

  test "the jobs are not executed synchronously" do
    ran = false

    job = Job.new(1) do
      sleep 0.1
      ran = true
    end

    @queue.push job
    assert_equal false, ran
  end

  test "shutting down the queue synchronously drains the jobs" do
    ran = false

    job = Job.new(1) do
      sleep 0.1
      ran = true
    end

    @queue.push job
    assert_equal false, ran

    @consumer.shutdown

    assert_equal true, ran
  end

  test "log job that raises an exception" do
    job = Job.new(1) do
      raise "RuntimeError: Error!"
    end

    @queue.push job
    sleep 0.1

    assert_equal 1, @logger.logged(:error).size
    assert_match(/Job Error: RuntimeError: Error!/, @logger.logged(:error).last)
  end

  test "test overriding exception handling" do
    @consumer.shutdown
    @consumer = Class.new(ActiveSupport::ThreadedQueueConsumer) do
      attr_reader :last_error
      def handle_exception(e)
        @last_error = e.message
      end
    end.start(@queue)

    job = Job.new(1) do
      raise "RuntimeError: Error!"
    end

    @queue.push job
    sleep 0.1

    assert_equal "RuntimeError: Error!", @consumer.last_error
  end
end
