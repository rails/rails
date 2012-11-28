require 'abstract_unit'
require 'active_support/queueing'
require "active_support/log_subscriber/test_helper"

class TestThreadConsumer < ActiveSupport::TestCase
  class Job
    attr_reader :id
    def initialize(id = 1, &block)
      @id = id
      @block = block
    end

    def run
      @block.call if @block
    end
  end

  def setup
    @logger = ActiveSupport::LogSubscriber::TestHelper::MockLogger.new
    @queue = ActiveSupport::Queue.new(logger: @logger)
  end

  def teardown
    @queue.drain
  end

  test "the jobs are executed" do
    ran = false
    job = Job.new { ran = true }

    @queue.push job
    @queue.drain

    assert_equal true, ran
  end

  test "the jobs are not executed synchronously" do
    run, ran = Queue.new, Queue.new
    job = Job.new { ran.push run.pop }

    @queue.consumer.start
    @queue.push job
    assert ran.empty?

    run.push true
    assert_equal true, ran.pop
  end

  test "shutting down the queue synchronously drains the jobs" do
    ran = false
    job = Job.new do
      sleep 0.1
      ran = true
    end

    @queue.consumer.start
    @queue.push job
    assert_equal false, ran

    @queue.consumer.shutdown
    assert_equal true, ran
  end

  test "log job that raises an exception" do
    job = Job.new { raise "RuntimeError: Error!" }

    @queue.push job
    consume_queue @queue

    assert_equal 1, @logger.logged(:error).size
    assert_match "Job Error: #{job.inspect}\nRuntimeError: Error!", @logger.logged(:error).last
  end

  test "logger defaults to stderr" do
    begin
      $stderr, old_stderr = StringIO.new, $stderr
      queue = ActiveSupport::Queue.new
      queue.push Job.new { raise "RuntimeError: Error!" }
      consume_queue queue
      assert_match 'Job Error', $stderr.string
    ensure
      $stderr = old_stderr
    end
  end

  test "test overriding exception handling" do
    @queue.consumer.instance_eval do
      def handle_exception(job, exception)
        @last_error = exception.message
      end

      def last_error
        @last_error
      end
    end

    job = Job.new { raise "RuntimeError: Error!" }

    @queue.push job
    consume_queue @queue

    assert_equal "RuntimeError: Error!", @queue.consumer.last_error
  end

  private
    def consume_queue(queue)
      queue.push nil
      queue.consumer.consume
    end
end
