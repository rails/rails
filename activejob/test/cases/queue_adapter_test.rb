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
    child_job_one.queue_adapter = :stub_one

    assert_not_equal ActiveJob::Base.queue_adapter, child_job_one.queue_adapter
    assert_kind_of ActiveJob::QueueAdapters::StubOneAdapter, child_job_one.queue_adapter

    child_job_two = Class.new(ActiveJob::Base)
    child_job_two.queue_adapter = :stub_two

    assert_kind_of ActiveJob::QueueAdapters::StubTwoAdapter, child_job_two.queue_adapter
    assert_kind_of ActiveJob::QueueAdapters::StubOneAdapter, child_job_one.queue_adapter, "child_job_one's queue adapter should remain unchanged"
    assert_equal base_queue_adapter, ActiveJob::Base.queue_adapter, "ActiveJob::Base's queue adapter should remain unchanged"

    child_job_three = Class.new(ActiveJob::Base)

    assert_not_nil child_job_three.queue_adapter
  end
end
