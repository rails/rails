require 'abstract_unit'
require 'rails/queueing'

class TestQueueTest < ActiveSupport::TestCase
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
    @queue = Rails::Queueing::TestQueue.new
  end

  def test_contents
    assert_equal [], @queue.contents
    job = Job.new(1)
    @queue.push job
    assert_equal [job], @queue.contents
  end

  def test_order
    time1 = time2 = nil

    job1 = Job.new(1) { time1 = Time.now }
    job2 = Job.new(2) { time2 = Time.now }

    @queue.push job1
    @queue.push job2
    @queue.drain

    assert time1 < time2, "Jobs run in the same order they were added"
  end

  def test_drain
    t = nil
    ran = false

    job = Job.new(1) do
      ran = true
      t = Thread.current
    end

    @queue.push job
    @queue.drain

    assert_equal [], @queue.contents
    assert ran, "The job runs synchronously when the queue is drained"
    assert_not_equal t, Thread.current
  end
end
