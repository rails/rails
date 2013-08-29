require 'abstract_unit'
require 'active_support/queueing'

class MultiQueueTest < ActiveSupport::TestCase
  include ActiveSupport

  def test_initialization_argument_is_default
    queue = new_queue
    assert_nil queue.default

    testQueue = TestQueue.new
    queue = new_queue(testQueue)
    assert_equal testQueue, queue.default

    syncQueue = SynchronousQueue.new
    queue = new_queue syncQueue
    assert_equal syncQueue, queue.default

    assert_equal queue.default, queue[:default]
  end

  def test_namespacing_queues
    queue = new_queue

    syncQueue = SynchronousQueue.new
    queue[:mail] = syncQueue
    assert_equal queue[:mail], syncQueue

    testQueue = TestQueue.new
    queue[:test] = testQueue
    assert_equal queue[:test], testQueue

    assert_nil queue.default
  end

  def test_passing_block_to_initialize_uses_custom_default
    stdQueue = ActiveSupport::Queue.new
    syncQueue = SynchronousQueue.new
    queue = new_queue do |hash, key|
      key.to_s.include?("mail") ? stdQueue : syncQueue
    end

    assert_equal stdQueue, queue[:mailer]
    assert_equal stdQueue, queue[:mail]
    assert_equal stdQueue, queue["mail-jobs"]

    assert_equal syncQueue, queue[:test]
    assert_equal syncQueue, queue[:mal]
    assert_equal syncQueue, queue["awesome-jobs"]

    assert_nil queue.default
  end

  def test_sending_methods_get_passed_to_default
    mock = MockQueue.new
    queue = new_queue mock

    assert_throws :error do
      queue.push
    end

    assert_throws :block do
      queue.run_block { throw :block }
    end

    assert_throws :argument_given do
      queue.run_block "arg" do
        throw :block
      end
    end
  end

  def test_multi_queue_allows_hash_methods
    queue = new_queue MockQueue.new
    queue[:sync] = SynchronousQueue.new

    assert_equal queue.default.member?, "answer"
    assert_equal queue.member?(:sync), true
  end

  def test_setting_default_after_initialization
    queue = new_queue
    assert_nil queue.default

    testQueue = TestQueue.new
    queue.default = testQueue
    assert_equal testQueue, queue.default
    assert_equal testQueue, queue[:random]
  end

  def test_jobs_are_ran
    ran = false
    job = Job.new { ran = true }

    queue = MultiQueue.default
    queue.push job
    queue.drain

    assert_equal true, ran
  end

  def test_jobs_are_not_executed_syncronously_with_default_queue
    run, ran = MultiQueue.default, MultiQueue.default
    job = Job.new { ran.push run.pop }

    queue = MultiQueue.default
    queue.consumer.start
    queue.push job
    assert ran.empty?

    run.push true
    assert_equal true, ran.pop
  end

  def test_mulit_queue_static_default
    queue = MultiQueue.default
    assert MultiQueue === queue
    assert ActiveSupport::Queue === queue.default
  end

  private
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

    def new_queue *args, &block
      if block_given?
        MultiQueue.new(*args, &block)
      else
        MultiQueue.new(*args, &block)
      end
    end

    class MockQueue
      def push
        throw :error
      end

      def run_block *args, &block
        throw :argument_given unless args.empty?
        block.call()
      end

      def member?
        "answer"
      end
    end
end