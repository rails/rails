require 'abstract_unit'
require 'rails/queueing'

class TestQueueTest < ActiveSupport::TestCase
  class Job
    def initialize(&block)
      @block = block
    end

    def run
      @block.call if @block
    end
  end

  def setup
    @queue = Rails::Queueing::TestQueue.new
  end

  def test_contents
    assert @queue.empty?
    job = Job.new
    @queue.push job
    refute @queue.empty?
    assert_equal job, @queue.pop
  end

  def test_order
    processed = []

    job1 = Job.new { processed << 1 }
    job2 = Job.new { processed << 2 }

    @queue.push job1
    @queue.push job2
    @queue.drain

    assert_equal [1,2], processed
  end

  def test_drain
    t = nil
    ran = false

    job = Job.new do
      ran = true
      t = Thread.current
    end

    @queue.push job
    @queue.drain

    assert @queue.empty?
    assert ran, "The job runs synchronously when the queue is drained"
    assert_not_equal t, Thread.current
  end
end
