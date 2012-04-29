require 'abstract_unit'
require 'rails/queueing'

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
    @queue = Queue.new
    @consumer = Rails::Queueing::ThreadedConsumer.start(@queue)
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
end
