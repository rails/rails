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
    def to_serializable_hash
      {}
    end
    def self.from_serializable_hash(hash)
      ExceptionRaisingJob.new
    end
  end

  def test_drain_raises_exceptions_from_running_jobs
    @queue.push ExceptionRaisingJob.new
    assert_raises(RuntimeError) { @queue.drain }
  end

  def test_jobs
    @queue.push Fixnum
    @queue.push String
    assert_equal [Fixnum,String], @queue.jobs
  end

  class EquivalentJob
    def initialize(id = nil)
      @initial_id = id || self.object_id
    end

    def to_serializable_hash
      {:initial_id => @initial_id}
    end
    def self.from_serializable_hash(hash)
      EquivalentJob.new(hash[:initial_id])
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

    def to_serializable_hash
      {:object => @object}
    end
    def self.from_serializable_hash(hash)
      ProcessingJob.new(hash[:object])
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
    class << self
      attr_accessor :thread_id
    end

    def to_serializable_hash
      {}
    end
    def self.from_serializable_hash(hash)
      ThreadTrackingJob.new
    end

    def run
      self.class.thread_id = Thread.current.object_id
    end

    def self.ran?
      thread_id
    end
  end

  def test_drain
    @queue.push ThreadTrackingJob.new
    @queue.drain

    assert @queue.empty?
    assert ThreadTrackingJob.ran?, "The job runs synchronously when the queue is drained"
    assert_equal ThreadTrackingJob.thread_id, Thread.current.object_id
  end

  class IdentifiableJob
    def initialize(id)
      @id = id
    end

    def to_serializable_hash
      {:id => @id}
    end
    def self.from_serializable_hash(hash)
      IdentifiableJob.new(hash[:id])
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

end
