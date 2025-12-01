# frozen_string_literal: true

require_relative "abstract_unit"

class ParallelizationTest < ActiveSupport::TestCase
  def setup
    @original_worker_id = ActiveSupport::TestCase.parallel_worker_id
  end

  def teardown
    ActiveSupport::TestCase.parallel_worker_id = @original_worker_id
  end

  test "parallel_worker_id is accessible as an attribute and method" do
    ActiveSupport::TestCase.parallel_worker_id = nil
    assert_nil ActiveSupport::TestCase.parallel_worker_id
    assert_nil parallel_worker_id
  end

  test "parallel_worker_id is set and accessible from class and instance" do
    ActiveSupport::TestCase.parallel_worker_id = 3

    assert_equal 3, ActiveSupport::TestCase.parallel_worker_id
    assert_equal 3, parallel_worker_id
  end

  test "parallel_worker_id persists across test subclasses" do
    ActiveSupport::TestCase.parallel_worker_id = 5

    subclass = Class.new(ActiveSupport::TestCase)
    assert_equal 5, subclass.parallel_worker_id

    instance = subclass.new("test")
    assert_equal 5, instance.parallel_worker_id
  end

  test "shutdown handles dead workers gracefully" do
    parallelization = ActiveSupport::Testing::Parallelization.new(1)
    parallelization.start

    sleep 0.25

    server = parallelization.instance_variable_get(:@queue_server)
    assert server.active_workers?

    worker_pids = parallelization.instance_variable_get(:@worker_pool)
    Process.kill("KILL", worker_pids.first)
    sleep 0.25

    Timeout.timeout(2.5, Minitest::Assertion, "Expected shutdown to not hang") { parallelization.shutdown }
    assert_not server.active_workers?
  end
end
