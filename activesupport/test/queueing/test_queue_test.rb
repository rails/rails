require 'abstract_unit'
require 'active_support/queueing'

class TestQueueTest < ActiveSupport::TestCase
  def setup
    @queue = ActiveSupport::TestQueue.new
  end

  class ExceptionRaisingJob
    def run
      raise
    end
  end

  def test_drain_raises_exceptions_from_running_jobs
    @queue.push ExceptionRaisingJob.new
    assert_raises(RuntimeError) { @queue.drain }
  end

  def test_jobs
    @queue.push 1
    @queue.push 2
    assert_equal [1,2], @queue.jobs
  end

  class EquivalentJob
    def initialize
      @initial_id = self.object_id
    end

    def run
    end

    def ==(other)
      other.same_initial_id?(@initial_id)
    end

    def same_initial_id?(other_id)
      other_id == @initial_id
    end
  end

  def test_contents
    job = EquivalentJob.new
    assert @queue.empty?
    @queue.push job
    refute @queue.empty?
    assert_equal job, @queue.pop
  end

  class ProcessingJob
    def self.clear_processed
      @processed = []
    end

    def self.processed
      @processed
    end

    def initialize(object)
      @object = object
    end

    def run
      self.class.processed << @object
    end
  end

  def test_order
    ProcessingJob.clear_processed
    job1 = ProcessingJob.new(1)
    job2 = ProcessingJob.new(2)

    @queue.push job1
    @queue.push job2
    @queue.drain

    assert_equal [1,2], ProcessingJob.processed
  end

  class ThreadTrackingJob
    attr_reader :thread_id

    def run
      @thread_id = Thread.current.object_id
    end

    def ran?
      @thread_id
    end
  end

  def test_drain
    @queue.push ThreadTrackingJob.new
    job = @queue.jobs.last
    @queue.drain

    assert @queue.empty?
    assert job.ran?, "The job runs synchronously when the queue is drained"
    assert_equal job.thread_id, Thread.current.object_id
  end

  class IdentifiableJob
    def initialize(id)
      @id = id
    end

    def ==(other)
      other.same_id?(@id)
    end

    def same_id?(other_id)
      other_id == @id
    end

    def run
    end
  end

  def test_queue_can_be_observed
    jobs = (1..10).map do |id|
      IdentifiableJob.new(id)
    end

    jobs.each do |job|
      @queue.push job
    end

    assert_equal jobs, @queue.jobs
  end

  def test_adding_an_unmarshallable_job
    anonymous_class_instance = Struct.new(:run).new

    assert_raises TypeError do
      @queue.push anonymous_class_instance
    end
  end

  def test_attempting_to_add_a_reference_to_itself
    job = {reference: @queue}
    assert_raises TypeError do
      @queue.push job
    end
  end
end
