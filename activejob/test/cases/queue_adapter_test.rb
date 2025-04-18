# frozen_string_literal: true

require "helper"

module ActiveJob
  module QueueAdapters
    class StubOneAdapter
      def enqueue(*); end
      def enqueue_at(*); end
    end

    class StubTwoAdapter
      def enqueue(*); end
      def enqueue_at(*); end
    end
  end
end

class QueueAdapterTest < ActiveJob::TestCase
  test "should forbid nonsense arguments" do
    assert_raises(ArgumentError) { ActiveJob::Base.queue_adapter = Mutex }
    assert_raises(ArgumentError) { ActiveJob::Base.queue_adapter = Mutex.new }
  end

  test "should allow overriding the queue_adapter at the child class level without affecting the parent or its sibling" do
    ActiveJob::Base.disable_test_adapter
    base_queue_adapter = ActiveJob::Base.queue_adapter

    child_job_one = Class.new(ActiveJob::Base)
    assert_equal child_job_one.queue_adapter_name, ActiveJob::Base.queue_adapter_name

    child_job_one.queue_adapter = :stub_one

    assert_not_equal ActiveJob::Base.queue_adapter, child_job_one.queue_adapter
    assert_equal "stub_one", child_job_one.queue_adapter_name
    assert_kind_of ActiveJob::QueueAdapters::StubOneAdapter, child_job_one.queue_adapter
    assert_kind_of ActiveJob::QueueAdapters::StubOneAdapter, child_job_one.new.queue_adapter

    child_job_two = Class.new(ActiveJob::Base)
    child_job_two.queue_adapter = :stub_two

    assert_equal "stub_two", child_job_two.queue_adapter_name

    assert_kind_of ActiveJob::QueueAdapters::StubTwoAdapter, child_job_two.queue_adapter
    assert_kind_of ActiveJob::QueueAdapters::StubTwoAdapter, child_job_two.new.queue_adapter
    assert_kind_of ActiveJob::QueueAdapters::StubOneAdapter, child_job_one.queue_adapter, "child_job_one's queue adapter should remain unchanged"
    assert_equal base_queue_adapter, ActiveJob::Base.queue_adapter, "ActiveJob::Base's queue adapter should remain unchanged"

    child_job_three = Class.new(ActiveJob::Base)

    assert_equal base_queue_adapter, child_job_three.queue_adapter, "child_job_three's queue adapter should remain unchanged"
  end

  test "should default to :async adapter if no adapters are set at all" do
    ActiveJob::Base.disable_test_adapter
    _queue_adapter_was = ActiveJob::Base._queue_adapter
    _queue_adapter_name_was = ActiveJob::Base._queue_adapter_name
    ActiveJob::Base._queue_adapter = ActiveJob::Base._queue_adapter_name = nil

    assert_equal "async", ActiveJob::Base.queue_adapter_name
    assert_kind_of ActiveJob::QueueAdapters::AsyncAdapter, ActiveJob::Base.queue_adapter
  ensure
    ActiveJob::Base._queue_adapter = _queue_adapter_was
    ActiveJob::Base._queue_adapter_name = _queue_adapter_name_was
  end

  test "should extract a reasonable name from a class instance" do
    child_job = Class.new(ActiveJob::Base)
    child_job.queue_adapter = ActiveJob::QueueAdapters::StubOneAdapter.new
    assert_equal "stub_one", child_job.queue_adapter_name
  end

  module StubThreeAdapter
    class << self
      def enqueue(*); end
      def enqueue_at(*); end
    end
  end

  test "should extract a reasonable name from a class or module" do
    child_job = Class.new(ActiveJob::Base)
    child_job.queue_adapter = StubThreeAdapter
    assert_equal "stub_three", child_job.queue_adapter_name
  end

  class StubFourAdapter
    def enqueue(*); end
    def enqueue_at(*); end
    def queue_adapter_name
      "fancy_name"
    end
  end

  test "should use the name provided by the adapter" do
    child_job = Class.new(ActiveJob::Base)
    child_job.queue_adapter = StubFourAdapter.new
    assert_equal "fancy_name", child_job.queue_adapter_name
  end
end
