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
