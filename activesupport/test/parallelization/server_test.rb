# frozen_string_literal: true

require_relative "../abstract_unit"

class FakeParallelizationReporter
  attr_reader :results

  def initialize
    @results = []
  end

  def synchronize
    yield
  end

  def prerecord(_klass, _name)
  end

  def record(result)
    @results << result
  end
end

class ServerTest < ActiveSupport::TestCase
  test "server tracks active workers" do
    distributor = ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)

    assert_not server.active_workers?

    server.start_worker("worker-1", 1234)
    assert server.active_workers?

    server.stop_worker("worker-1")
    assert_not server.active_workers?
  end

  test "server removes dead workers" do
    distributor = ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)

    server.start_worker("worker-1", 1234)
    server.start_worker("worker-2", 5678)
    assert server.active_workers?

    server.remove_dead_workers([1234])
    assert server.active_workers?  # worker-2 still active

    server.remove_dead_workers([5678])
    assert_not server.active_workers?  # all workers gone
  end

  test "record_worker_errors records worker errors as failed results" do
    distributor = ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)
    reporter = FakeParallelizationReporter.new

    result = Minitest::Result.new("test_passes")
    result.klass = "SomeTest"
    server.record(reporter, result)

    error = RuntimeError.new("cleanup failed in worker 0")
    error.set_backtrace(["test.rb:1:in 'block'"])
    server.report_worker_error(0, error)

    server.record_worker_errors

    assert_equal 2, reporter.results.size
    failure = reporter.results.last
    assert_equal "parallelize_teardown", failure.name
    assert_equal "Parallelization worker 0", failure.klass
    assert_equal 1, failure.failures.size
    assert_includes failure.failures.first.message, "cleanup failed in worker 0"
  end

  test "record_worker_errors raises when no result was ever recorded" do
    distributor = ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)

    server.report_worker_error(1, RuntimeError.new("cleanup failed in worker 1"))

    error = assert_raises(RuntimeError) { server.record_worker_errors }
    assert_includes error.message, "parallelize_teardown failed"
    assert_includes error.message, "worker 1"
  end
end
